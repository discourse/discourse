require 'spec_helper'
require 'message_bus'

describe MessageBus::ReliablePubSub do

  def new_test_bus
    MessageBus::ReliablePubSub.new(:db => 10)
  end

  before do
    @bus = new_test_bus
    @bus.reset!
  end

  it "should be able to access the backlog" do
    @bus.publish "/foo", "bar"
    @bus.publish "/foo", "baz"

    @bus.backlog("/foo", 0).to_a.should == [
      MessageBus::Message.new(1,1,'/foo','bar'),
      MessageBus::Message.new(2,2,'/foo','baz')
    ]
  end

  it "should truncate channels correctly" do
    @bus.max_backlog_size = 2
    4.times do |t|
      @bus.publish "/foo", t.to_s
    end

    @bus.backlog("/foo").to_a.should == [
      MessageBus::Message.new(3,3,'/foo','2'),
      MessageBus::Message.new(4,4,'/foo','3'),
    ]
  end

  it "should be able to grab a message by id" do
    id1 = @bus.publish "/foo", "bar"
    id2 = @bus.publish "/foo", "baz"
    @bus.get_message("/foo", id2).should == MessageBus::Message.new(2, 2, "/foo", "baz")
    @bus.get_message("/foo", id1).should == MessageBus::Message.new(1, 1, "/foo", "bar")
  end

  it "should be able to access the global backlog" do
    @bus.publish "/foo", "bar"
    @bus.publish "/hello", "world"
    @bus.publish "/foo", "baz"
    @bus.publish "/hello", "planet"

    @bus.global_backlog.to_a.should == [
      MessageBus::Message.new(1, 1, "/foo", "bar"),
      MessageBus::Message.new(2, 1, "/hello", "world"),
      MessageBus::Message.new(3, 2, "/foo", "baz"),
      MessageBus::Message.new(4, 2, "/hello", "planet")
    ]
  end

  it "should correctly omit dropped messages from the global backlog" do
    @bus.max_backlog_size = 1
    @bus.publish "/foo", "a"
    @bus.publish "/foo", "b"
    @bus.publish "/bar", "a"
    @bus.publish "/bar", "b"

    @bus.global_backlog.to_a.should == [
      MessageBus::Message.new(2, 2, "/foo", "b"),
      MessageBus::Message.new(4, 2, "/bar", "b")
    ]
  end

  it "should have the correct number of messages for multi threaded access" do
    threads = []
    4.times do
      threads << Thread.new do
        bus = new_test_bus
        25.times {
          bus.publish "/foo", "."
        }
      end
    end

    threads.each{|t| t.join}
    @bus.backlog("/foo").length == 100
  end

  it "should be able to subscribe globally with recovery" do
    @bus.publish("/foo", "1")
    @bus.publish("/bar", "2")
    got = []

    t = Thread.new do
      new_test_bus.global_subscribe(0) do |msg|
        got << msg
      end
    end

    @bus.publish("/bar", "3")

    wait_for(100) do
      got.length == 3
    end

    t.kill

    got.length.should == 3
    got.map{|m| m.data}.should == ["1","2","3"]
  end

  it "should be able to encode and decode messages properly" do
    m = MessageBus::Message.new 1,2,'||','||'
    MessageBus::Message.decode(m.encode).should == m
  end

  it "should handle subscribe on single channel, with recovery" do
    @bus.publish("/foo", "1")
    @bus.publish("/bar", "2")
    got = []

    t = Thread.new do
      new_test_bus.subscribe("/foo",0) do |msg|
        got << msg
      end
    end

    @bus.publish("/foo", "3")

    wait_for(100) do
      got.length == 2
    end

    t.kill

    got.map{|m| m.data}.should == ["1","3"]
  end

  it "should not get backlog if subscribe is called without params" do
    @bus.publish("/foo", "1")
    got = []

    t = Thread.new do
      new_test_bus.subscribe("/foo") do |msg|
        got << msg
      end
    end

    # sleep 50ms to allow the bus to correctly subscribe,
    #   I thought about adding a subscribed callback, but outside of testing it matters less
    sleep 0.05

    @bus.publish("/foo", "2")

    wait_for(100) do
      got.length == 1
    end

    t.kill

    got.map{|m| m.data}.should == ["2"]
  end

  it "should allow us to get last id on a channel" do
    @bus.last_id("/foo").should == 0
    @bus.publish("/foo", "1")
    @bus.last_id("/foo").should == 1
  end

end
