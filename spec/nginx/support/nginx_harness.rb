# frozen_string_literal: true

require "fileutils"
require "net/http"
require "socket"
require "tmpdir"
require_relative "config_renderer"
require_relative "nginx_executable"

module Nginx
  module Support
    # Owns the lifecycle of an upstream and nginx subprocess pair.
    # `start` brings both up; `stop` tears both down. `get` / `request` send
    # HTTP to nginx and return the response.
    class NginxHarness
      HTTP_TIMEOUT_SECONDS = 5

      attr_reader :listen_port, :upstream_port, :tmpdir

      def initialize(upstream:, sample_path: default_sample_path, public_path: nil)
        @sample_path = sample_path
        @upstream = upstream
        @public_path = public_path
        @tmpdir = nil
        @nginx_pid = nil
        @upstream_started = false
        @listen_port = nil
        @upstream_port = nil
      end

      def start
        @tmpdir = Dir.mktmpdir("nginx-spec-")
        @upstream.start
        @upstream_started = true
        @upstream_port = @upstream.port

        @listen_port = allocate_port
        render_and_spawn_nginx
        wait_for_port(@listen_port, "nginx") or
          raise_with_logs("nginx never bound to port #{@listen_port}")
        self
      rescue StandardError
        stop
        raise
      end

      def stop
        stop_nginx
        stop_upstream
      ensure
        FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
        @tmpdir = nil
      end

      # Convenience: `harness.get("/", headers: {...})` returns
      # Net::HTTPResponse. Body and headers are inspectable on the result.
      def get(path, headers: {})
        request(:get, path, headers: headers)
      end

      def request(method, path, headers: {}, body: nil)
        uri = URI("http://127.0.0.1:#{@listen_port}#{path}")
        req_class =
          case method.to_s.downcase
          when "get"
            Net::HTTP::Get
          when "post"
            Net::HTTP::Post
          when "head"
            Net::HTTP::Head
          when "put"
            Net::HTTP::Put
          when "delete"
            Net::HTTP::Delete
          else
            raise ArgumentError, "unsupported method #{method.inspect}"
          end
        req = req_class.new(uri)
        headers.each { |k, v| req[k] = v }
        req.body = body if body
        Net::HTTP.start(
          uri.host,
          uri.port,
          open_timeout: HTTP_TIMEOUT_SECONDS,
          read_timeout: HTTP_TIMEOUT_SECONDS,
        ) { |http| http.request(req) }
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise_with_logs(
          "#{method.to_s.upcase} #{path} timed out after #{HTTP_TIMEOUT_SECONDS}s (#{e.class}: #{e.message})",
        )
      end

      def nginx_access_log
        return "" if @tmpdir.nil?

        path = File.join(@tmpdir, "access.log")
        return "" unless File.exist?(path)

        File.read(path)
      end

      private

      def stop_upstream
        return unless @upstream_started

        @upstream.stop
      ensure
        @upstream_started = false
      end

      def render_and_spawn_nginx
        renderer =
          ConfigRenderer.new(
            tmpdir: @tmpdir,
            sample_path: @sample_path,
            upstream_port: @upstream_port,
            listen_port: @listen_port,
            public_path: @public_path,
          )
        wrapper_path = renderer.render

        @nginx_pid =
          Process.spawn(
            NginxExecutable.path || "nginx",
            "-c",
            wrapper_path,
            "-p",
            @tmpdir,
            out: File.join(@tmpdir, "nginx-stdout.log"),
            err: File.join(@tmpdir, "nginx-stderr.log"),
          )
      end

      def stop_nginx
        return unless @nginx_pid
        Process.kill("TERM", @nginx_pid)
        deadline = Time.now + 5
        loop do
          break if Process.waitpid(@nginx_pid, Process::WNOHANG)
          if Time.now > deadline
            begin
              Process.kill("KILL", @nginx_pid)
            rescue StandardError
              nil
            end
            begin
              Process.waitpid(@nginx_pid, Process::WNOHANG)
            rescue StandardError
              nil
            end
            break
          end
          sleep 0.05
        end
      rescue Errno::ECHILD, Errno::ESRCH
        # Already reaped or never started — fine.
      ensure
        @nginx_pid = nil
      end

      def allocate_port
        # Bind to port 0, read what the kernel assigned, immediately close.
        # Brief race window before we re-bind, but adequate for tests.
        server = TCPServer.new("127.0.0.1", 0)
        port = server.addr[1]
        server.close
        port
      end

      def wait_for_port(port, label, timeout: 5)
        deadline = Time.now + timeout
        loop do
          return true if port_open?(port)
          return false if Time.now > deadline
          sleep 0.05
        end
      end

      def port_open?(port)
        TCPSocket.new("127.0.0.1", port).tap(&:close)
        true
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
        false
      end

      def raise_with_logs(message)
        details = []
        %w[nginx-stderr.log nginx-stdout.log error.log].each do |name|
          path = File.join(@tmpdir, name)
          next unless File.exist?(path)
          details << "--- #{name} ---\n#{File.read(path)}"
        end
        raise "#{message}\n#{details.join("\n")}"
      end

      def default_sample_path
        File.expand_path("../../../config/nginx.sample.conf", __dir__)
      end
    end
  end
end
