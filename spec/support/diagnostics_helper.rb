module MessageBus::DiagnosticsHelper
  def publish(channel, data, opts = nil)
    id = super(channel, data, opts)
    if @tracking
      m = MessageBus::Message.new(-1, id, channel, data)
      m.user_ids = opts[:user_ids] if opts
      m.group_ids = opts[:group_ids] if opts
      @tracking << m
    end
    id
  end

  def track_publish
    @tracking = tracking =  []
    yield
    @tracking = nil
    tracking
  end
end

module MessageBus
  extend MessageBus::DiagnosticsHelper
end
