# frozen_string_literal: true

require "json"
require "tmpdir"
require "timeout"
require_relative "browser_web_socket"

class DiscourseBidiClient
  def initialize(executable:, profile:, &on_event)
    @on_event = on_event
    @mutex = Mutex.new
    @pending = {}
    @sequence = 0
    errors, browser_errors = IO.pipe
    @error_pipe_read = errors
    @error_pipe_write = browser_errors
    launch_args = [executable]
    launch_args << "--headless" unless ENV["PLAYWRIGHT_HEADLESS"] == "0"
    @pid =
      Process.spawn(
        *launch_args,
        "--remote-debugging-port=0",
        "--profile",
        profile,
        in: File::NULL,
        out: File::NULL,
        err: browser_errors,
        pgroup: true,
      )
    browser_errors.close
    @error_pipe_write = nil
    endpoint = Queue.new
    @errors =
      Thread.new do
        errors.each_line do |line|
          if url = line[%r{WebDriver BiDi listening on (ws://\S+)}, 1]
            endpoint << "#{url}/session"
          end
        end
      end
    url = endpoint.pop(timeout: 10)
    raise "Firefox did not start WebDriver BiDi" unless url
    @socket = BrowserWebSocket.new(url)
    @reader = Thread.new { read_events }
    command("session.new", capabilities: { alwaysMatch: {} })
  rescue StandardError
    quit
    raise
  end

  def command(method, params = {})
    response_queue = Queue.new
    id = nil
    @mutex.synchronize do
      @sequence += 1
      id = @sequence
      @pending[id] = response_queue
      @socket.write(JSON.generate(id: id, method: method, params: params))
    end
    response = response_queue.pop(timeout: 30)
    raise Timeout::Error, "BiDi command timed out: #{method}" unless response
    raise response if response.is_a?(Exception)
    raise "#{method}: #{response.fetch("message")}" if response["type"] == "error"
    result = response.fetch("result")
    sleep(ENV["PLAYWRIGHT_SLOW_MO_MS"].to_i / 1000.0) if ENV["PLAYWRIGHT_SLOW_MO_MS"]
    result
  ensure
    @mutex.synchronize { @pending.delete(id) } if id
  end

  def quit
    @socket&.close
  ensure
    stop_browser_process
    @reader&.join(1)
    @errors&.join(1)
    @error_pipe_read&.close unless @error_pipe_read&.closed?
    @error_pipe_write&.close unless @error_pipe_write&.closed?
    @pid = nil
  end

  private

  def stop_browser_process
    return unless @pid
    begin
      Process.kill("TERM", -@pid)
    rescue Errno::ESRCH
      nil
    end
    begin
      Process.wait(@pid)
    rescue Errno::ECHILD
      nil
    end
  end

  def read_events
    while message = @socket.read
      response = JSON.parse(message)
      if response.key?("id")
        queue = @mutex.synchronize { @pending.delete(response.fetch("id")) }
        queue << response if queue
      else
        @on_event.call(response)
      end
    end
  rescue StandardError => error
    fail_pending(error)
  ensure
    fail_pending(IOError.new("Firefox WebDriver BiDi connection closed"))
  end

  def fail_pending(error)
    @mutex.synchronize do
      @pending.each_value { |queue| queue << error }
      @pending.clear
    end
  end
end
