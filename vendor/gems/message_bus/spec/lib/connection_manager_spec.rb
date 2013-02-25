require 'spec_helper'
require 'message_bus'

class FakeAsync

  attr_accessor :cleanup_timer

  def <<(val)
    @sent ||= ""
    @sent << val
  end

  def sent; @sent; end
  def done; @done = true; end
  def done?; @done; end
end

class FakeTimer
  attr_accessor :cancelled
  def cancel; @cancelled = true; end
end

describe MessageBus::ConnectionManager do

  before do
    @manager = MessageBus::ConnectionManager.new
    @client = MessageBus::Client.new(client_id: "xyz", user_id: 1, site_id: 10)
    @resp = FakeAsync.new
    @client.async_response = @resp
    @client.subscribe('test', -1)
    @manager.add_client(@client)
    @client.cleanup_timer = FakeTimer.new
  end

  it "should cancel the timer after its responds" do
    m = MessageBus::Message.new(1,1,"test","data")
    m.site_id = 10
    @manager.notify_clients(m)
    @client.cleanup_timer.cancelled.should == true
  end

  it "should be able to lookup an identical client" do
    @manager.lookup_client(@client.client_id).should == @client
  end

  it "should be subscribed to a channel" do
    @manager.stats[:subscriptions][10]["test"].length == 1
  end

  it "should not notify clients on incorrect site" do
    m = MessageBus::Message.new(1,1,"test","data")
    m.site_id = 9
    @manager.notify_clients(m)
    @resp.sent.should == nil
  end

  it "should notify clients on the correct site" do
    m = MessageBus::Message.new(1,1,"test","data")
    m.site_id = 10
    @manager.notify_clients(m)
    @resp.sent.should_not == nil
  end

  it "should strip site id and user id from the payload delivered" do
    m = MessageBus::Message.new(1,1,"test","data")
    m.user_ids = [1]
    m.site_id = 10
    @manager.notify_clients(m)
    parsed = JSON.parse(@resp.sent)
    parsed[0]["site_id"].should == nil
    parsed[0]["user_id"].should == nil
  end

  it "should not deliver unselected" do
    m = MessageBus::Message.new(1,1,"test","data")
    m.user_ids = [5]
    m.site_id = 10
    @manager.notify_clients(m)
    @resp.sent.should == nil
  end


end
