# frozen_string_literal: true

require "socket"
require "uri"
require "websocket/driver"

class BrowserWebSocket
  class SocketAdapter
    attr_reader :url

    def initialize(socket, url)
      @socket = socket
      @url = url
      @mutex = Mutex.new
    end

    def write(bytes)
      @mutex.synchronize { @socket.write(bytes) }
    end
  end

  def initialize(url, origin: nil)
    uri = URI(url)
    @socket = TCPSocket.new(uri.host, uri.port)
    @messages = Queue.new
    @driver_mutex = Mutex.new
    @driver = WebSocket::Driver.client(SocketAdapter.new(@socket, url))
    @driver.set_header("Origin", origin) if origin
    @driver.on(:message) { |event| @messages << event.data }
    @driver.on(:close) { @messages << nil }
    @driver.on(:error) { |event| @messages << RuntimeError.new(event.message) }
    @driver.start
    @reader =
      Thread.new do
        loop do
          bytes = @socket.readpartial(16_384)
          @driver_mutex.synchronize { @driver.parse(bytes) }
        end
      rescue EOFError, IOError, SystemCallError
        @messages << nil
      rescue StandardError => error
        @messages << error
      end
  end

  def write(message)
    @driver_mutex.synchronize { @driver.text(message) }
  end

  def read
    message = @messages.pop
    raise message if message.is_a?(Exception)
    message
  end

  def close
    @driver_mutex.synchronize { @driver.close }
  rescue IOError, SystemCallError
    nil
  ensure
    @socket.close
    @reader&.join(1)
  end
end
