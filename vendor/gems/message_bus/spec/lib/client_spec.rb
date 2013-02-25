require 'spec_helper'
require 'message_bus'

describe MessageBus::Client do

  describe "subscriptions" do

    before do
      @client = MessageBus::Client.new :client_id => 'abc'
    end

    it "should provide a list of subscriptions" do
      @client.subscribe('/hello', nil)
      @client.subscriptions['/hello'].should_not be_nil
    end

    it "should provide backlog for subscribed channel" do
      @client.subscribe('/hello', nil)
      MessageBus.publish '/hello', 'world'
      log = @client.backlog
      log.length.should == 1
      log[0].channel.should == '/hello'
      log[0].data.should == 'world'
    end
  end

end
