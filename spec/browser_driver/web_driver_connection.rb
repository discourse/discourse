# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "socket"
require "tmpdir"

class WebDriverConnection
  class ProtocolError < SystemBrowserError
    attr_reader :code

    def initialize(code:, message:)
      # Safari omits the standard prefix for intercepted clicks.
      @code = code == "click intercepted" ? "element click intercepted" : code
      super(message)
    end
  end

  def initialize(
    url,
    executable_path:,
    bind_host: nil,
    url_setting: "WebDriver URL",
    environment: {}
  )
    @executable_path = executable_path
    @driver_name = File.basename(executable_path)
    @bind_host = bind_host
    @url_setting = url_setting
    @environment = environment
    @remote = parse_url(url) if url && !url.empty?
  end

  def remote? = !@remote.nil?

  def start
    return if @http
    if remote?
      connect(@remote)
      return
    end

    host = @bind_host || "127.0.0.1"
    port = TCPServer.open(host, 0) { |server| server.local_address.ip_port }
    endpoint = URI::HTTP.build(port:)
    endpoint.hostname = host
    arguments = @bind_host ? ["--host=#{host}", "--port=#{port}"] : ["--port", port.to_s]

    @directory = Dir.mktmpdir("discourse-webdriver-")
    log = File.join(@directory, "webdriver.log")
    @pid =
      Process.spawn(@environment, @executable_path, *arguments, in: File::NULL, out: log, err: log)
    wait_for_service(endpoint, log:)
  rescue Errno::ENOENT => error
    close
    raise SystemBrowserError, "#{@driver_name} executable is unavailable: #{error.message}"
  rescue StandardError
    close
    raise
  end

  def request(method, path:, payload: nil)
    start
    perform_request(method, path:, payload:)
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => error
    raise SystemBrowserTimeout, "#{@driver_name} #{method} #{path} timed out: #{error.message}"
  rescue SystemCallError,
         IOError,
         SocketError,
         Net::HTTPBadResponse,
         OpenSSL::SSL::SSLError => error
    raise SystemBrowserError, "#{@driver_name} #{method} #{path} failed: #{error.message}"
  end

  def close
    @http.finish if @http&.started?
  ensure
    @http = nil
    stop_service if @pid
    FileUtils.remove_entry(@directory) if @directory
    @directory = nil
  end

  private

  def parse_url(url)
    endpoint = URI(url)
    unless endpoint.is_a?(URI::HTTP) && endpoint.hostname && !endpoint.query && !endpoint.fragment
      raise ArgumentError, "#{@url_setting} must be an HTTP or HTTPS WebDriver endpoint"
    end
    endpoint
  rescue URI::InvalidURIError
    raise ArgumentError, "#{@url_setting} must be an HTTP or HTTPS WebDriver endpoint"
  end

  def connect(endpoint)
    @endpoint = endpoint
    @prefix = endpoint.path.delete_suffix("/")
    @http = Net::HTTP.new(endpoint.hostname, endpoint.port, nil)
    @http.use_ssl = endpoint.scheme == "https"
    @http.open_timeout = 2
    @http.read_timeout = 15
    @http.write_timeout = 15
    @http.max_retries = 0
  end

  def perform_request(method, path:, payload: nil)
    request = Net::HTTPGenericRequest.new(method, !payload.nil?, true, @prefix + path)
    if @endpoint.user
      user = URI::DEFAULT_PARSER.unescape(@endpoint.user)
      password = URI::DEFAULT_PARSER.unescape(@endpoint.password.to_s)
      request.basic_auth(user, password)
    end
    unless payload.nil?
      request.content_type = "application/json"
      request.body = JSON.generate(payload)
    end
    @http.start unless @http.started?
    response = @http.request(request)
    body = JSON.parse(response.body.to_s)
    value = body.fetch("value") if body.is_a?(Hash)
    if value.is_a?(Hash) && value["error"].is_a?(String) && !response.is_a?(Net::HTTPSuccess)
      message = "#{@driver_name} #{method} #{path}: #{value["error"]}: #{value["message"]}"
      raise ProtocolError.new(code: value.fetch("error"), message:)
    end
    unless body.is_a?(Hash) && response.is_a?(Net::HTTPSuccess)
      raise SystemBrowserError,
            "Unexpected #{@driver_name} response to #{method} #{path} (HTTP #{response.code})"
    end
    value
  rescue JSON::ParserError, KeyError
    raise SystemBrowserError,
          "Invalid #{@driver_name} response to #{method} #{path} (HTTP #{response.code})"
  end

  def wait_for_service(endpoint, log:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    loop do
      if Process.waitpid(@pid, Process::WNOHANG)
        @pid = nil
        raise SystemBrowserError, "#{@driver_name} exited during launch: #{File.read(log).strip}"
      end

      begin
        connect(endpoint)
        status = perform_request("GET", path: "/status")
        return if status.is_a?(Hash) && status["ready"]
        raise SystemBrowserError, "#{@driver_name} is unavailable: #{status.inspect}"
      rescue Errno::ECONNREFUSED
        @http = nil
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise SystemBrowserTimeout, "#{@driver_name} did not start: #{File.read(log).strip}"
        end
        sleep 0.05
      end
    end
  end

  def stop_service
    Process.kill("TERM", @pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    until Process.waitpid(@pid, Process::WNOHANG)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        Process.kill("KILL", @pid)
        Process.waitpid(@pid)
        break
      end
      sleep 0.05
    end
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  ensure
    @pid = nil
  end
end
