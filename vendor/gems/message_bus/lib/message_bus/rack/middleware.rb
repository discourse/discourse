# our little message bus, accepts long polling and web sockets
require 'thin'
require 'eventmachine'

module MessageBus::Rack; end

class MessageBus::Rack::Middleware

  def self.start_listener
    unless @started_listener
      MessageBus.subscribe do |msg|
        if EM.reactor_running?
          EM.next_tick do
            @@connection_manager.notify_clients(msg) if @@connection_manager
          end
        end
      end
      @started_listener = true
    end
  end

  def initialize(app, config = {})
    @app = app
    @@connection_manager = MessageBus::ConnectionManager.new
    self.class.start_listener
  end

  def self.backlog_to_json(backlog)
    m = backlog.map do |msg|
      {
        :global_id => msg.global_id,
        :message_id => msg.message_id,
        :channel => msg.channel,
        :data => msg.data
      }
    end.to_a
    JSON.dump(m)
  end

  def call(env)

    return @app.call(env) unless env['PATH_INFO'] =~ /^\/message-bus/

    # special debug/test route
    if ::MessageBus.allow_broadcast? && env['PATH_INFO'] == '/message-bus/broadcast'
        parsed = Rack::Request.new(env)
        ::MessageBus.publish parsed["channel"], parsed["data"]
        return [200,{"Content-Type" => "text/html"},["sent"]]
    end

    if env['PATH_INFO'].start_with? '/message-bus/_diagnostics'
      diags = MessageBus::Rack::Diagnostics.new(@app)
      return diags.call(env)
    end

    client_id = env['PATH_INFO'].split("/")[2]
    return [404, {}, ["not found"]] unless client_id

    user_id = MessageBus.user_id_lookup.call(env) if MessageBus.user_id_lookup
    site_id = MessageBus.site_id_lookup.call(env) if MessageBus.site_id_lookup

    client = MessageBus::Client.new(client_id: client_id, user_id: user_id, site_id: site_id)

    connection = env['em.connection']

    request = Rack::Request.new(env)
    request.POST.each do |k,v|
      client.subscribe(k, v)
    end

    backlog = client.backlog
    headers = {}
    headers["Cache-Control"] = "must-revalidate, private, max-age=0"
    headers["Content-Type"] ="application/json; charset=utf-8"

    if backlog.length > 0
      [200, headers, [self.class.backlog_to_json(backlog)] ]
    elsif MessageBus.long_polling_enabled? && env['QUERY_STRING'] !~ /dlp=t/ && EM.reactor_running?
      response = Thin::AsyncResponse.new(env)
      response.headers["Cache-Control"] = "must-revalidate, private, max-age=0"
      response.headers["Content-Type"] ="application/json; charset=utf-8"
      response.status = 200
      client.async_response = response

      @@connection_manager.add_client(client)

      client.cleanup_timer = ::EM::Timer.new(MessageBus.long_polling_interval.to_f / 1000) {
        client.close
        @@connection_manager.remove_client(client)
      }

      throw :async
    else
      [200, headers, ["[]"]]
    end

  end
end

# there is also another in cramp this is from https://github.com/macournoyer/thin_async/blob/master/lib/thin/async.rb
module Thin
  unless defined?(DeferrableBody)
    # Based on version from James Tucker <raggi@rubyforge.org>
    class DeferrableBody
      include ::EM::Deferrable

      def initialize
        @queue = []
      end

      def call(body)
        @queue << body
        schedule_dequeue
      end

      def each(&blk)
        @body_callback = blk
        schedule_dequeue
      end

      private
        def schedule_dequeue
          return unless @body_callback
          ::EM.next_tick do
            next unless body = @queue.shift
            body.each do |chunk|
              @body_callback.call(chunk)
            end
            schedule_dequeue unless @queue.empty?
          end
        end
    end
  end

  # Response whos body is sent asynchronously.
  class AsyncResponse
    include Rack::Response::Helpers

    attr_reader :headers, :callback, :closed
    attr_accessor :status

    def initialize(env, status=200, headers={})
      @callback = env['async.callback']
      @body = DeferrableBody.new
      @status = status
      @headers = headers
      @headers_sent = false
    end

    def send_headers
      return if @headers_sent
      @callback.call [@status, @headers, @body]
      @headers_sent = true
    end

    def write(body)
      send_headers
      @body.call(body.respond_to?(:each) ? body : [body])
    end
    alias :<< :write

    # Tell Thin the response is complete and the connection can be closed.
    def done
      @closed = true
      send_headers
      ::EM.next_tick { @body.succeed }
    end

  end
end
