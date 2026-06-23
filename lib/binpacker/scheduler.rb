# frozen_string_literal: true

module Binpacker
  class Scheduler
    def partition(tests:, worker_count:, timings:)
      raise NotImplementedError
    end

    def self.for(strategy)
      case strategy.to_s
      when "lpt" then LptScheduler.new
      when "multifit" then MultifitScheduler.new
      else
        raise SchedulerError, "unknown scheduling algorithm: #{strategy}"
      end
    end

    private

    def weight(test, timings)
      timings.fetch(test.key, Timing::DEFAULT_WEIGHT)
    end

    def sorted_by_weight(tests, timings)
      tests.sort_by { |t| -weight(t, timings) }
    end
  end

  class LptScheduler < Scheduler
    def partition(tests:, worker_count:, timings:)
      queues = Array.new(worker_count) { |i| WorkerQueue.new(i) }
      loads = Array.new(worker_count, 0.0)

      sorted_by_weight(tests, timings).each do |test|
        min_idx = loads.each_with_index.min_by { |load, _| load }.last
        queues[min_idx].push(test)
        loads[min_idx] += weight(test, timings)
      end

      queues
    end
  end

  class MultifitScheduler < Scheduler
    ITERATIONS = 7

    def partition(tests:, worker_count:, timings:)
      sorted = sorted_by_weight(tests, timings)

      upper = lpt_makespan(sorted, worker_count, timings)
      lower = [max_weight(sorted, timings), total_weight(sorted, timings) / worker_count.to_f].max

      best_queues = nil
      ITERATIONS.times do
        mid = (upper + lower) / 2.0
        queues = first_fit_decreasing(sorted, worker_count, mid, timings)

        if queues
          best_queues = queues
          upper = mid
        else
          lower = mid
        end
      end

      best_queues || LptScheduler.new.partition(tests: tests, worker_count: worker_count, timings: timings)
    end

    private

    def lpt_makespan(sorted, worker_count, timings)
      loads = Array.new(worker_count, 0.0)
      sorted.each do |test|
        min_idx = loads.each_with_index.min_by { |l, _| l }.last
        loads[min_idx] += weight(test, timings)
      end
      loads.max
    end

    def max_weight(sorted, timings)
      sorted.map { |t| weight(t, timings) }.max || 0.0
    end

    def total_weight(sorted, timings)
      sorted.sum { |t| weight(t, timings) }
    end

    def first_fit_decreasing(sorted, worker_count, capacity, timings)
      queues = Array.new(worker_count) { |i| WorkerQueue.new(i) }
      loads = Array.new(worker_count, 0.0)

      sorted.each do |test|
        w = weight(test, timings)
        idx = loads.each_with_index.find { |l, _| l + w <= capacity }&.last

        return nil unless idx

        queues[idx].push(test)
        loads[idx] += w
      end

      queues
    end
  end
end
