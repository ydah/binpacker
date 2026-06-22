# frozen_string_literal: true

module Binpacker
  Test = Struct.new(:file, :name, keyword_init: true) do
    def key
      [file, name]
    end
  end

  class TestDiscovery
    def initialize(config)
      @config = config
      @pattern = config.test_pattern
      @exclude = config.test_exclude
    end

    def enumerate
      raise NotImplementedError
    end

    private

    def glob_files
      Dir.glob(@pattern).reject { |f|
        @exclude.any? { |ex| File.fnmatch?(ex, f) }
      }
    end
  end

  class RSpecDiscovery < TestDiscovery
    def enumerate
      glob_files.map { |f| Test.new(file: f, name: f) }
    end
  end

  class MinitestDiscovery < TestDiscovery
    def enumerate
      require "minitest"
      def Minitest.autorun; end
      Minitest.seed = 42

      tests = []
      glob_files.each do |file|
        begin
          klasses_before = Minitest::Runnable.runnables.dup
          load File.expand_path(file)

          (Minitest::Runnable.runnables - klasses_before).each do |klass|
            klass.runnable_methods.each do |method_name|
              tests << Test.new(file: file, name: "#{klass}##{method_name}")
            end
          end
        rescue => e
          $stderr.puts "minitest discovery: failed to load #{file}: #{e.message}"
        end
      end
      tests
    end
  end
end
