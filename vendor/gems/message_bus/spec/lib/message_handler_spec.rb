require 'spec_helper'
require 'message_bus'

describe MessageBus::MessageHandler do

  it "should properly register message handlers" do
    MessageBus::MessageHandler.handle "/hello" do |m|
      m
    end
    MessageBus::MessageHandler.call("site","/hello", "world", 1).should == "world"
  end

  it "should correctly load message handlers" do
    MessageBus::MessageHandler.load_handlers("#{File.dirname(__FILE__)}/handlers")
    MessageBus::MessageHandler.call("site","/dupe", "1", 1).should == "11"
  end

  it "should allow for a connect / disconnect callback" do
    MessageBus::MessageHandler.handle "/channel" do |m|
      m
    end

    connected = false
    disconnected = false

    MessageBus.on_connect do |site_id|
      connected = true
    end
    MessageBus.on_disconnect do |site_id|
      disconnected = true
    end

    MessageBus::MessageHandler.call("site_id", "/channel", "data", 1)

    connected.should == true
    disconnected.should == true

  end
end
