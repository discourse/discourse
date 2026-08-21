# frozen_string_literal: true

require "etc"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "nginx_executable"

# Reads `config/nginx.sample.conf` and rewrites the handful of references
# that don't work outside a deployed Discourse environment: hardcoded
# upstream port, log/cache filesystem paths, and the `conf.d/outlets/...`
# customization-hook includes. Writes the result plus a tiny wrapper
# (`events { ... }` + `http { include ...; }`) into a tmpdir so we can
# invoke `nginx -c <wrapper> -p <tmpdir>`.
#
# Optional nginx modules (brotli today; potentially others later) that
# the system's nginx cannot use in this generated wrapper get commented
# out so the test suite runs against a stock nginx. Tests that need a
# stripped directive should skip themselves when `module_available?`
# reports it missing.
module Nginx
  module Support
    class ConfigRenderer
      MODULE_PROBES = {
        "brotli" => [
          "brotli on;",
          "brotli_min_length 1000;",
          "brotli_comp_level 4;",
          "brotli_types text/plain;",
          "brotli_static on;",
        ],
      }.freeze

      WRAPPER_TEMPLATE = <<~CONF
        # Generated for tests — do not edit by hand.
        # Wraps nginx.sample.conf with the events+http blocks it omits.
        %<worker_user_directive>sworker_processes 1;
        daemon off;
        error_log %<error_log>s warn;
        pid %<pid_file>s;

        events {
          worker_connections 256;
        }

        http {
          include %<mime_types>s;
          default_type application/octet-stream;
          client_body_temp_path %<tmpdir>s/client_body_temp;
          proxy_temp_path %<tmpdir>s/proxy_temp;
          fastcgi_temp_path %<tmpdir>s/fastcgi_temp;
          uwsgi_temp_path %<tmpdir>s/uwsgi_temp;
          scgi_temp_path %<tmpdir>s/scgi_temp;

          include %<sample>s;
        }
      CONF

      attr_reader :tmpdir, :sample_path, :upstream_port, :listen_port

      def initialize(tmpdir:, sample_path:, upstream_port:, listen_port:)
        @tmpdir = tmpdir
        @sample_path = sample_path
        @upstream_port = upstream_port
        @listen_port = listen_port
      end

      # Returns the path to the wrapper nginx.conf the harness should pass
      # to `nginx -c`.
      def render
        FileUtils.mkdir_p(File.join(tmpdir, "cache"))
        FileUtils.mkdir_p(File.join(tmpdir, "logs"))
        FileUtils.mkdir_p(File.join(tmpdir, "public"))
        FileUtils.mkdir_p(File.join(tmpdir, "outlets/before-server"))
        FileUtils.mkdir_p(File.join(tmpdir, "outlets/server"))

        rewritten = rewrite_sample(File.read(sample_path))
        sample_out = File.join(tmpdir, "discourse.conf")
        File.write(sample_out, rewritten)

        wrapper =
          format(
            WRAPPER_TEMPLATE,
            tmpdir: tmpdir,
            sample: sample_out,
            mime_types: system_mime_types,
            error_log: File.join(tmpdir, "error.log"),
            pid_file: File.join(tmpdir, "nginx.pid"),
            worker_user_directive: worker_user_directive,
          )
        wrapper_path = File.join(tmpdir, "nginx.conf")
        File.write(wrapper_path, wrapper)
        wrapper_path
      end

      # Whether the system's nginx can use this module's directives in the
      # generated test wrapper. Dynamic modules can appear in `nginx -V` output
      # but still be unavailable unless a separate `load_module` directive runs,
      # so probe a tiny standalone config instead of trusting build flags.
      def self.module_available?(name)
        @module_cache ||= {}
        @module_cache.fetch(name) { @module_cache[name] = module_directive_usable?(name) }
      end

      def self.nginx_bin
        NginxExecutable.path || "nginx"
      end

      def self.nginx_build_flags
        # argv-style (not a shell) so an NGINX_BIN path with spaces is the
        # same executable the spawn/module-probe paths run. nginx writes
        # its build flags to stderr, so merge both streams.
        @nginx_build_flags ||=
          begin
            stdout, stderr, _status = Open3.capture3(nginx_bin, "-V")
            stdout + stderr
          rescue SystemCallError
            ""
          end
      end

      def self.module_directive_usable?(name)
        Dir.mktmpdir("nginx-module-probe-") do |tmpdir|
          config_path = File.join(tmpdir, "nginx.conf")
          File.write(config_path, module_probe_config(tmpdir, name))

          !!system(
            nginx_bin,
            "-t",
            "-c",
            config_path,
            "-p",
            tmpdir,
            out: File::NULL,
            err: File::NULL,
          )
        end
      rescue SystemCallError
        false
      end

      def self.module_probe_config(tmpdir, name)
        directives = MODULE_PROBES.fetch(name) { ["#{name} on;"] }

        [
          "worker_processes 1;",
          "error_log #{File.join(tmpdir, "error.log")} warn;",
          "pid #{File.join(tmpdir, "nginx.pid")};",
          "",
          "events {",
          "  worker_connections 16;",
          "}",
          "",
          "http {",
          *directives.map { |directive| "  #{directive}" },
          "}",
        ].join("\n") + "\n"
      end
      private_class_method :module_directive_usable?, :module_probe_config

      private

      def worker_user_directive
        return "" if Process.euid.nonzero?

        user = Etc.getpwuid(Process.euid).name
        group = Etc.getgrgid(Process.egid).name
        "user #{user} #{group};\n"
      end

      def rewrite_sample(source)
        source =
          source
            .gsub("server 127.0.0.1:3000;", "server 127.0.0.1:#{upstream_port};")
            .gsub("listen 80;", "listen 127.0.0.1:#{listen_port};")
            .gsub("/var/nginx/cache", File.join(tmpdir, "cache"))
            .gsub("/var/log/nginx/access.log", File.join(tmpdir, "access.log"))
            .gsub("/var/log/nginx/error.log", File.join(tmpdir, "error.log"))
            .gsub("/var/www/discourse/public", File.join(tmpdir, "public"))
            .gsub("conf.d/outlets/", File.join(tmpdir, "outlets/"))

        # Comment out directives belonging to nginx modules that the generated
        # wrapper cannot use. We do this with a regex rather than listing every
        # directive name so future additions (e.g. ngx_pagespeed) work too.
        unless ConfigRenderer.module_available?("brotli")
          source = comment_directives(source, /\bbrotli(_[a-z_]+)?\b/)
        end

        source
      end

      def comment_directives(source, prefix_regex)
        source
          .lines
          .map do |line|
            if line =~ /^\s*#{prefix_regex.source}/
              "# [test-harness disabled] #{line}"
            else
              line
            end
          end
          .join
      end

      def system_mime_types
        # nginx ships its own mime.types; locate it via `nginx -V`'s
        # configured --prefix/--conf-path or fall back to /etc/nginx/mime.types.
        build_flags = ConfigRenderer.nginx_build_flags
        prefix = build_flags[/--prefix=(\S+)/, 1]
        conf_path = build_flags[/--conf-path=(\S+)/, 1]
        candidates = [
          prefix && File.join(prefix, "conf/mime.types"),
          conf_path && File.join(File.dirname(conf_path), "mime.types"),
          "/etc/nginx/mime.types",
        ].compact
        candidates.find { |p| File.exist?(p) } || candidates.first
      end
    end
  end
end
