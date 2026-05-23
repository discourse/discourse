# frozen_string_literal: true

require "tmpdir"
require_relative "config_renderer"

RSpec.describe Nginx::Support::ConfigRenderer do
  describe "#render" do
    it "runs nginx workers as the test process user when root spawns nginx" do
      Dir.mktmpdir do |tmpdir|
        name_entry = Struct.new(:name)
        sample_path = File.join(tmpdir, "nginx.sample.conf")
        File.write(sample_path, "")

        allow(Process).to receive(:euid).and_return(0)
        allow(Process).to receive(:egid).and_return(0)
        allow(Etc).to receive(:getpwuid).with(0).and_return(name_entry.new("root"))
        allow(Etc).to receive(:getgrgid).with(0).and_return(name_entry.new("root"))
        allow(described_class).to receive(:module_available?).with("brotli").and_return(true)
        allow(described_class).to receive(:nginx_build_flags).and_return("")

        renderer =
          described_class.new(
            tmpdir: tmpdir,
            sample_path: sample_path,
            upstream_port: 3001,
            listen_port: 3002,
          )

        expect(File.read(renderer.render)).to include("user root root;\nworker_processes 1;")
      end
    end
  end

  describe ".module_available?" do
    before do
      described_class.instance_variable_set(:@module_cache, {})
      described_class.remove_instance_variable(:@nginx_build_flags) if build_flags_cached?
    end

    after do
      described_class.remove_instance_variable(:@module_cache) if module_cache_exists?
      described_class.remove_instance_variable(:@nginx_build_flags) if build_flags_cached?
    end

    it "memoizes missing modules" do
      allow(described_class).to receive(:nginx_build_flags).once.and_return("")

      expect(described_class.module_available?("brotli")).to eq(false)
      expect(described_class.module_available?("brotli")).to eq(false)
    end

    def module_cache_exists?
      described_class.instance_variable_defined?(:@module_cache)
    end

    def build_flags_cached?
      described_class.instance_variable_defined?(:@nginx_build_flags)
    end
  end
end
