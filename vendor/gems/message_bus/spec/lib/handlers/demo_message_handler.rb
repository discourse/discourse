class DemoMessageHandler < MessageBus::MessageHandler
  handle "/dupe" do |m, uid|
    "#{m}#{m}"
  end
end
