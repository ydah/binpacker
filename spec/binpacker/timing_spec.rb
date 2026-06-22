# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "binpacker/timing"
require "binpacker/test_discovery"

RSpec.describe Binpacker::Timing do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  let(:path) { File.join(@dir, "binpacker.timings") }
  subject(:timing) { described_class.new(path) }

  describe "UTF-8 handling" do
    let(:unicode_file) { "spec/テスト_spec.rb" }
    let(:unicode_name) { "テスト 正常系 ユーザー登録" }
    let(:elapsed) { 1.23 }

    describe "#append and #load_raw" do
      it "roundtrips a UTF-8 test name" do
        timing.append(file: unicode_file, name: unicode_name, time: elapsed)

        raw = timing.load_raw
        expect(raw).to have_key([unicode_file, unicode_name])
      end

      it "preserves the elapsed time for a UTF-8 entry" do
        timing.append(file: unicode_file, name: unicode_name, time: elapsed)

        raw = timing.load_raw
        expect(raw[[unicode_file, unicode_name]]).to be_within(0.001).of(elapsed)
      end

      it "writes the file in UTF-8 encoding" do
        timing.append(file: unicode_file, name: unicode_name, time: elapsed)

        content = File.read(path, encoding: "UTF-8")
        expect(content.encoding).to eq(Encoding::UTF_8)
        expect(content).to include("テスト_spec.rb")
        expect(content).to include("テスト 正常系 ユーザー登録")
      end

      it "returns strings with UTF-8 encoding" do
        timing.append(file: unicode_file, name: unicode_name, time: elapsed)

        raw = timing.load_raw
        key = raw.keys.first
        expect(key[0].encoding).to eq(Encoding::UTF_8)
        expect(key[1].encoding).to eq(Encoding::UTF_8)
      end
    end

    describe "#append_all and #load_per_file" do
      let(:entries) do
        [
          { file: unicode_file, name: "#{unicode_name} 1", time: 0.5 },
          { file: unicode_file, name: "#{unicode_name} 2", time: 1.0 }
        ]
      end

      it "roundtrips multiple UTF-8 entries" do
        timing.append_all(entries)

        per_file = timing.load_per_file
        normalized = timing.normalize_path(unicode_file)
        expect(per_file).to have_key(normalized)
      end

      it "sums times for UTF-8 entries in the same file" do
        timing.append_all(entries)

        per_file = timing.load_per_file
        normalized = timing.normalize_path(unicode_file)
        expect(per_file[normalized]).to be_within(0.001).of(1.5)
      end
    end

    describe "#load_with_fallback" do
      it "matches UTF-8 test file paths against timing data" do
        timing.append(file: unicode_file, name: unicode_name, time: elapsed)

        test = Binpacker::Test.new(file: unicode_file, name: unicode_name)
        weights = timing.load_with_fallback([test])
        expect(weights[test.key]).to be_within(0.001).of(elapsed)
      end
    end
  end
end
