# frozen_string_literal: true

require "tmpdir"
require_relative "config_renderer"

RSpec.describe Nginx::Support::ConfigRenderer do
  describe "#render" do
    it "uses mime.types next to nginx --conf-path when the prefix candidate is absent" do
      Dir.mktmpdir do |tmpdir|
        conf_dir = File.join(tmpdir, "etc/nginx")
        FileUtils.mkdir_p(conf_dir)
        mime_types = File.join(conf_dir, "mime.types")
        File.write(mime_types, "types {}\n")
        sample_path = File.join(tmpdir, "nginx.sample.conf")
        File.write(sample_path, "")

        allow(described_class).to receive(:module_available?).with("brotli").and_return(true)
        allow(described_class).to receive(:nginx_build_flags).and_return(
          "--prefix=#{File.join(tmpdir, "prefix")} --conf-path=#{File.join(conf_dir, "nginx.conf")}",
        )

        renderer =
          described_class.new(
            tmpdir: tmpdir,
            sample_path: sample_path,
            upstream_port: 3001,
            listen_port: 3002,
          )

        expect(File.read(renderer.render)).to include("include #{mime_types};")
      end
    end

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

    it "rewrites the sample's upstream port, listen port, and filesystem paths" do
      Dir.mktmpdir do |tmpdir|
        sample_path = File.join(tmpdir, "nginx.sample.conf")
        File.write(sample_path, <<~CONF)
          server 127.0.0.1:3000;
          listen 80;
          proxy_cache_path /var/nginx/cache keys_zone=one:10m;
          access_log /var/log/nginx/access.log;
          error_log /var/log/nginx/error.log;
          root /var/www/discourse/public;
          include conf.d/outlets/discourse/*.conf;
        CONF

        allow(described_class).to receive(:module_available?).with("brotli").and_return(true)
        allow(described_class).to receive(:nginx_build_flags).and_return("")

        renderer =
          described_class.new(
            tmpdir: tmpdir,
            sample_path: sample_path,
            upstream_port: 3001,
            listen_port: 3002,
          )

        renderer.render
        rendered = File.read(File.join(tmpdir, "discourse.conf"))

        expect(rendered).to include("server 127.0.0.1:3001;")
        expect(rendered).to include("listen 127.0.0.1:3002;")
        expect(rendered).to include("#{tmpdir}/cache")
        expect(rendered).to include("#{tmpdir}/access.log")
        expect(rendered).to include("#{tmpdir}/error.log")
        expect(rendered).to include("#{tmpdir}/public")
        expect(rendered).to include("include #{tmpdir}/outlets/discourse/*.conf;")

        # The pre-substitution values must be gone, or a typo'd gsub would
        # pass this test while leaking production paths into the rendered conf.
        expect(rendered).not_to include("127.0.0.1:3000")
        expect(rendered).not_to include("listen 80;")
        expect(rendered).not_to include("/var/nginx/cache")
        expect(rendered).not_to include("/var/log/nginx/")
        expect(rendered).not_to include("/var/www/discourse/public")
        expect(rendered).not_to include("conf.d/outlets/")
      end
    end
  end

  describe ".module_available?" do
    before { described_class.instance_variable_set(:@module_cache, {}) }

    after { described_class.remove_instance_variable(:@module_cache) if module_cache_exists? }

    it "does not trust build flags when nginx rejects the directive probe" do
      allow(described_class).to receive(:nginx_build_flags).and_return(
        "--add-dynamic-module=/tmp/ngx_brotli",
      )
      allow(described_class).to receive(:system).and_return(false)

      expect(described_class.module_available?("brotli")).to eq(false)
      expect(described_class).not_to have_received(:nginx_build_flags)
    end

    it "returns true when nginx accepts the directive probe" do
      allow(described_class).to receive(:system).and_return(true)

      expect(described_class.module_available?("brotli")).to eq(true)
    end

    it "memoizes rejected module probes" do
      allow(described_class).to receive(:system).once.and_return(false)

      expect(described_class.module_available?("brotli")).to eq(false)
      expect(described_class.module_available?("brotli")).to eq(false)
    end

    def module_cache_exists?
      described_class.instance_variable_defined?(:@module_cache)
    end
  end
end
