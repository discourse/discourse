require 'spec_helper'
require 'message_bus'
require 'redis'


describe MessageBus do

  before do
    MessageBus.site_id_lookup do
      "magic"
    end
    MessageBus.redis_config = {}
  end

  it "should automatically decode hashed messages" do
    data = nil
    MessageBus.subscribe("/chuck") do |msg|
      data = msg.data
    end
    MessageBus.publish("/chuck", {:norris => true})
    wait_for(1000){ data }

    data["norris"].should == true
  end

  it "should get a message if it subscribes to it" do
    @data,@site_id,@channel = nil

    MessageBus.subscribe("/chuck") do |msg|
      @data = msg.data
      @site_id = msg.site_id
      @channel = msg.channel
      @user_ids = msg.user_ids
    end

    MessageBus.publish("/chuck", "norris", user_ids: [1,2,3])

    wait_for(1000){@data}

    @data.should == 'norris'
    @site_id.should == 'magic'
    @channel.should == '/chuck'
    @user_ids.should == [1,2,3]

  end


  it "should get global messages if it subscribes to them" do
    @data,@site_id,@channel = nil

    MessageBus.subscribe do |msg|
      @data = msg.data
      @site_id = msg.site_id
      @channel = msg.channel
    end

    MessageBus.publish("/chuck", "norris")

    wait_for(1000){@data}

    @data.should == 'norris'
    @site_id.should == 'magic'
    @channel.should == '/chuck'
  end

  it "should have the ability to grab the backlog messages in the correct order" do
    id = MessageBus.publish("/chuck", "norris")
    MessageBus.publish("/chuck", "foo")
    MessageBus.publish("/chuck", "bar")

    r = MessageBus.backlog("/chuck", id)

    r.map{|i| i.data}.to_a.should == ['foo', 'bar']
  end

end
