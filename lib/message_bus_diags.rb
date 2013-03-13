class MessageBusDiags

  @host_info = {}

  def self.my_id
    @my_id ||= "#{`hostname`}-#{Process.pid}"
  end

  def self.seen_host(name)
    @host_info[name] = DateTime.now
  end

  def self.establish_peer_names
    MessageBus.publish "/server-name", {channel: "/server-name-reply/#{my_id}"}
  end

  def self.seen_hosts
    @host_info
  end

  unless @subscribed

    MessageBus.subscribe "/server-name-reply/#{my_id}" do |msg|
      MessageBusDiags.seen_host(msg.data)
    end

    MessageBus.subscribe "/server-name" do |msg|
      MessageBus.publish msg.data["channel"], MessageBusDiags.my_id
    end
    @subscribed = true
  end
end
