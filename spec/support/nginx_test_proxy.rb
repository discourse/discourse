# frozen_string_literal: true

require "fileutils"
require "net/http"
require "socket"
require "tmpdir"

class NginxTestProxy
  attr_reader :port

  def self.available?
    executable.present?
  end

  def self.executable
    override = ENV["NGINX_BIN"]
    return override if override.present? && File.executable?(override)

    ENV
      .fetch("PATH", "")
      .split(File::PATH_SEPARATOR)
      .map { |path| File.join(path, "nginx") }
      .find { |path| File.file?(path) && File.executable?(path) }
  end

  def initialize(upstream_port:)
    @upstream_port = upstream_port
  end

  def start
    @tmpdir = Dir.mktmpdir("nginx-spec-")
    @port = available_port
    FileUtils.mkdir_p(File.join(@tmpdir, "cache"))
    FileUtils.mkdir_p(File.join(@tmpdir, "outlets"))
    FileUtils.mkdir_p(File.join(@tmpdir, "outlets", "discourse"))
    File.write(
      File.join(@tmpdir, "outlets", "discourse", "test.conf"),
      "add_header X-Nginx-Discourse-Fallback true always;\n",
    )
    File.write(sample_config_path, test_config)
    File.write(wrapper_config_path, wrapper_config)

    @pid =
      Process.spawn(
        self.class.executable,
        "-c",
        wrapper_config_path,
        "-p",
        @tmpdir,
        "-e",
        File.join(@tmpdir, "startup-error.log"),
        out: File.join(@tmpdir, "stdout.log"),
        err: File.join(@tmpdir, "stderr.log"),
      )

    wait_until_ready
    self
  rescue StandardError
    stop
    raise
  end

  def stop
    if @pid
      Process.kill("TERM", @pid)
      Process.wait(@pid)
    end
  rescue Errno::ECHILD, Errno::ESRCH
    nil
  ensure
    @pid = nil
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
    @tmpdir = nil
  end

  def url
    "http://127.0.0.1:#{port}"
  end

  def get(path)
    Net::HTTP.get_response(URI("#{url}#{path}"))
  end

  def access_log
    path = File.join(@tmpdir, "access.log")
    File.exist?(path) ? File.read(path) : ""
  end

  private

  def test_config
    File
      .read(Rails.root.join("config/nginx.sample.conf"))
      .gsub("server 127.0.0.1:3000;", "server 127.0.0.1:#{@upstream_port};")
      .gsub("listen 80;", "listen 127.0.0.1:#{port};")
      .gsub("/var/nginx/cache", File.join(@tmpdir, "cache"))
      .gsub("/var/log/nginx/access.log", File.join(@tmpdir, "access.log"))
      .gsub("/var/log/nginx/error.log", File.join(@tmpdir, "error.log"))
      .gsub("/var/www/discourse/public", Rails.root.join("frontend/discourse/dist").to_s)
      .gsub("conf.d/outlets/", File.join(@tmpdir, "outlets/"))
      .lines
      .map { |line| line.match?(/^\s*brotli/) ? "# #{line}" : line }
      .join
  end

  def wrapper_config
    <<~NGINX
      worker_processes 1;
      daemon off;
      error_log #{File.join(@tmpdir, "error.log")} warn;
      pid #{File.join(@tmpdir, "nginx.pid")};

      events {
        worker_connections 256;
      }

      http {
        include #{mime_types_path};
        default_type application/octet-stream;
        client_body_temp_path #{File.join(@tmpdir, "client_body_temp")};
        proxy_temp_path #{File.join(@tmpdir, "proxy_temp")};
        fastcgi_temp_path #{File.join(@tmpdir, "fastcgi_temp")};
        uwsgi_temp_path #{File.join(@tmpdir, "uwsgi_temp")};
        scgi_temp_path #{File.join(@tmpdir, "scgi_temp")};
        include #{sample_config_path};
      }
    NGINX
  end

  def mime_types_path
    executable = self.class.executable
    candidates = [
      ENV["NGINX_MIME_TYPES"],
      executable && File.expand_path("../conf/mime.types", File.dirname(executable)),
      "/etc/nginx/mime.types",
    ]

    candidates.compact.find { |path| File.file?(path) } || raise("nginx mime.types not found")
  end

  def wait_until_ready
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5

    loop do
      TCPSocket.new("127.0.0.1", port).close
      return
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
      raise nginx_error if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
  end

  def nginx_error
    logs =
      %w[stderr.log stdout.log error.log].filter_map do |filename|
        path = File.join(@tmpdir, filename)
        "--- #{filename} ---\n#{File.read(path)}" if File.exist?(path)
      end
    "nginx did not start on port #{port}\n#{logs.join("\n")}"
  end

  def available_port
    TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
  end

  def sample_config_path
    File.join(@tmpdir, "discourse.conf")
  end

  def wrapper_config_path
    File.join(@tmpdir, "nginx.conf")
  end
end
