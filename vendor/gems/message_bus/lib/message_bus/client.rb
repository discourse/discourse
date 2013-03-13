class MessageBus::Client
  attr_accessor :client_id, :user_id, :connect_time, :subscribed_sets, :site_id, :cleanup_timer, :async_response
  def initialize(opts)
    self.client_id = opts[:client_id]
    self.user_id = opts[:user_id]
    self.site_id = opts[:site_id]
    self.connect_time = Time.now
    @subscriptions = {}
  end

  def close
    return unless @async_response
    write_and_close "[]"
  end

  def closed
    !@async_response
  end

  def subscribe(channel, last_seen_id)
    last_seen_id ||= MessageBus.last_id(channel)
    @subscriptions[channel] = last_seen_id
  end

  def subscriptions
    @subscriptions
  end

  def <<(msg)
    write_and_close messages_to_json([msg])
  end

  def subscriptions
    @subscriptions
  end

  def backlog
    r = []
    @subscriptions.each do |k,v|
      next if v.to_i < 0
      messages = MessageBus.backlog(k,v)
      messages.each do |msg|
        allowed = !msg.user_ids || msg.user_ids.include?(self.user_id)
        r << msg if allowed
      end
    end
    # stats message for all newly subscribed
    status_message = nil
    @subscriptions.each do |k,v|
      if v.to_i == -1
        status_message ||= {}
        status_message[k] = MessageBus.last_id(k)
      end
    end
    r << MessageBus::Message.new(-1, -1, '/__status', status_message) if status_message
    r
  end

  protected

  def write_and_close(data)
    @async_response << data
    @async_response.done
    @async_response = nil
  end

  def messages_to_json(msgs)
    MessageBus::Rack::Middleware.backlog_to_json(msgs)
  end
end
