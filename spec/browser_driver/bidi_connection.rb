# frozen_string_literal: true

require "json"
require "openssl"
require "socket"
require "uri"

class SystemBrowserProtocolError < SystemBrowserError
  attr_reader :code

  def initialize(code, message)
    @code = code
    super(message)
  end
end

class BrowserWebSocket
  attr_reader :url

  def initialize(url, &on_event)
    require "websocket/driver"

    @url = url
    @on_event = on_event
    @state_mutex = Mutex.new
    @wire_mutex = Mutex.new
    @opened = Queue.new
    @pending = {}
    @received = []
    @sequence = 0

    endpoint = URI(url)
    @socket = Socket.tcp(endpoint.hostname, endpoint.port, connect_timeout: 5)
    if endpoint.scheme == "wss"
      context = OpenSSL::SSL::SSLContext.new
      context.set_params
      @socket =
        OpenSSL::SSL::SSLSocket
          .new(@socket, context)
          .tap do |secure_socket|
            secure_socket.hostname = endpoint.hostname
            secure_socket.sync_close = true
            secure_socket.connect
          end
    end

    @websocket = WebSocket::Driver.client(self)
    @websocket.on(:open) { @opened << true }
    @websocket.on(:message) { |message| @received << message.data }
    @websocket.on(:error) { |error| @failure = SystemBrowserError.new(error.message) }
    @websocket.start
    @reader = Thread.new { read_messages }
    raise SystemBrowserTimeout, "Browser WebSocket did not open" unless @opened.pop(timeout: 5)
    raise @failure if @failure
  rescue StandardError
    close
    raise
  end

  def write(bytes)
    @socket.write(bytes)
  end

  def command(method, params = {})
    reply = Queue.new
    id = send_request(method, params, reply)
    response = reply.pop(timeout: 30)
    raise SystemBrowserTimeout, "Browser command timed out: #{method}" unless response
    raise response if response.is_a?(Exception)
    if response["error"]
      raise SystemBrowserProtocolError.new(response["error"], "#{method}: #{response["message"]}")
    end
    response.fetch("result")
  ensure
    @state_mutex.synchronize { @pending.delete(id) } if id
  end

  def notify(method, params = {})
    send_request(method, params, nil)
    nil
  end

  def close
    @socket&.close unless @socket&.closed?
    @reader&.join(1) unless @reader == Thread.current
  end

  private

  def send_request(method, params, reply)
    id =
      @state_mutex.synchronize do
        raise @failure if @failure
        @sequence += 1
        @pending[@sequence] = reply if reply
        @sequence
      end
    @wire_mutex.synchronize { @websocket.text(JSON.generate({ id:, method:, params: })) }
    id
  rescue IOError, SystemCallError, OpenSSL::SSL::SSLError => error
    @state_mutex.synchronize { @pending.delete(id) } if id
    raise SystemBrowserError, error.message
  end

  def read_messages
    loop do
      input = @socket.readpartial(65_536)
      messages =
        @wire_mutex.synchronize do
          @websocket.parse(input)
          @received.shift(@received.size)
        end
      raise @failure if @failure
      messages.each do |data|
        message = JSON.parse(data)
        if message["id"]
          reply = @state_mutex.synchronize { @pending[message["id"]] }
          reply << message if reply
        else
          @on_event&.call(message)
        end
      end
    end
  rescue StandardError => error
    failure = error.is_a?(SystemBrowserError) ? error : SystemBrowserError.new(error.message)
    @state_mutex.synchronize do
      @failure = failure
      @pending.each_value { |reply| reply << failure }
      @pending.clear
    end
    @opened << false
  end
end
