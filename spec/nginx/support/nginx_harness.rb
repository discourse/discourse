# frozen_string_literal: true

require "fileutils"
require "net/http"
require "socket"
require "stringio"
require "tmpdir"
require "webrick"
require_relative "config_renderer"
require_relative "mock_upstream"
require_relative "nginx_executable"

module Nginx
  module Support
    # Owns the lifecycle of one (mock upstream, nginx subprocess) pair.
    # `start` brings both up; `stop` tears both down. `get` / `request`
    # send HTTP to nginx and return the response.
    class NginxHarness
      HTTP_TIMEOUT_SECONDS = 5

      attr_reader :listen_port, :upstream_port, :tmpdir

      def initialize(sample_path: default_sample_path)
        @sample_path = sample_path
        @tmpdir = nil
        @nginx_pid = nil
        @upstream_thread = nil
        @upstream_server = nil
        @listen_port = nil
        @upstream_port = nil
      end

      def start
        @tmpdir = Dir.mktmpdir("nginx-spec-")
        @upstream_port = allocate_port
        start_upstream

        @listen_port = allocate_port
        render_and_spawn_nginx
        wait_for_port(@listen_port, "nginx") or
          raise_with_logs("nginx never bound to port #{@listen_port}")
      end

      def stop
        stop_nginx
        stop_upstream
      ensure
        FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
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

      def start_upstream
        # WEBrick's log is noisy on stderr; redirect to a file under tmpdir
        # so test output stays clean but we keep it for failure forensics.
        log = WEBrick::Log.new(File.join(@tmpdir, "upstream.log"), WEBrick::Log::WARN)
        access = [
          [
            File.open(File.join(@tmpdir, "upstream-access.log"), "w"),
            WEBrick::AccessLog::COMMON_LOG_FORMAT,
          ],
        ]
        @upstream_server =
          WEBrick::HTTPServer.new(
            BindAddress: "127.0.0.1",
            Port: @upstream_port,
            Logger: log,
            AccessLog: access,
          )
        @upstream_server.mount_proc("/") do |req, res|
          rack_env = build_rack_env(req)
          status, headers, body = MockUpstream.new.call(rack_env)
          res.status = status
          headers.each { |k, v| res[k] = v }
          res.body = body.join
        end
        @upstream_thread = Thread.new { @upstream_server.start }
        wait_for_port(@upstream_port, "mock upstream") or
          raise_with_logs("mock upstream never bound to port #{@upstream_port}")
      end

      def stop_upstream
        @upstream_server&.shutdown
        @upstream_thread&.join(5)
      end

      def render_and_spawn_nginx
        renderer =
          ConfigRenderer.new(
            tmpdir: @tmpdir,
            sample_path: @sample_path,
            upstream_port: @upstream_port,
            listen_port: @listen_port,
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
        %w[
          nginx-stderr.log
          nginx-stdout.log
          error.log
          upstream.log
          upstream-access.log
        ].each do |name|
          path = File.join(@tmpdir, name)
          next unless File.exist?(path)
          details << "--- #{name} ---\n#{File.read(path)}"
        end
        raise "#{message}\n#{details.join("\n")}"
      end

      def build_rack_env(webrick_req)
        env = {
          "REQUEST_METHOD" => webrick_req.request_method,
          "PATH_INFO" => webrick_req.path,
          "QUERY_STRING" => webrick_req.query_string || "",
          "rack.input" => StringIO.new(webrick_req.body || ""),
          MockUpstream::ORIGINAL_HEADER_NAMES_ENV => original_header_names(webrick_req),
        }
        webrick_req.header.each do |name, values|
          # WEBrick gives header values as arrays; join with comma per RFC.
          rack_key = "HTTP_" + name.upcase.tr("-", "_")
          env[rack_key] = Array(values).join(", ")
        end
        env
      end

      def original_header_names(webrick_req)
        Array(webrick_req.raw_header).each_with_object({}) do |line, names|
          next unless (raw_name = line[/\A([^:\s]+):/, 1])

          rack_key = "HTTP_" + raw_name.upcase.tr("-", "_")
          names[rack_key] ||= raw_name
        end
      end

      def default_sample_path
        File.expand_path("../../../config/nginx.sample.conf", __dir__)
      end
    end
  end
end
