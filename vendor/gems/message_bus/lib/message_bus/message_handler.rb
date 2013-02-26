class MessageBus::MessageHandler
  def self.load_handlers(path)
    Dir.glob("#{path}/*.rb").each do |f|
      load "#{f}"
    end
  end

  def self.handle(name,&blk)
    raise ArgumentError.new("expecting block") unless block_given?
    raise ArgumentError.new("name") unless name

    @@handlers ||= {}
    @@handlers[name] = blk
  end

  def self.call(site_id, name, data, current_user_id)
    begin
      MessageBus.on_connect.call(site_id) if MessageBus.on_connect
      @@handlers[name].call(data,current_user_id)
    ensure
      MessageBus.on_disconnect.call(site_id) if MessageBus.on_disconnect
    end
  end


end
