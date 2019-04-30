# frozen_string_literal: true

module MessageBus::DiagnosticsHelper
  def publish(channel, data, opts = nil)
    id = super(channel, data, opts)
    if @tracking && (@channel.nil? || @channel == channel)
      m = MessageBus::Message.new(-1, id, channel, data)
      m.user_ids = opts[:user_ids] if opts
      m.group_ids = opts[:group_ids] if opts
      @tracking << m
    end
    id
  end

  def track_publish(channel = nil)
    @channel = channel
    @tracking = tracking = []
    yield
    tracking
  ensure
    @tracking = nil
  end

end

module MessageBus
  extend MessageBus::DiagnosticsHelper
end
