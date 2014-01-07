require 'spec_helper'
require 'cache'

describe Cache do

  let :cache do
    Cache.new
  end

  it "supports fixnum" do
    cache.write("num", 1)
    cache.read("num").should == 1
  end

  it "supports hash" do
    hash = {a: 1, b: [1,2,3]}
    cache.write("hash", hash)
    cache.read("hash").should == hash
  end

  it "can be cleared" do
    cache.write("hello0", "world")
    cache.write("hello1", "world")
    cache.clear

    cache.read("hello0").should be_nil
  end

  it "can delete by family" do
    cache.write("key2", "test", family: "my_family")
    cache.write("key", "test", expires_in: 1.minute, family: "my_family")

    cache.delete_by_family("my_family")

    cache.fetch("key").should be_nil
    cache.fetch("key2").should be_nil

  end

  it "can delete correctly" do
    cache.fetch("key", expires_in: 1.minute) do
      "test"
    end

    cache.delete("key")
    cache.fetch("key").should be_nil
  end

  #TODO yuck on this mock
  it "calls setex in redis" do
    cache.delete("key")

    key = cache.namespaced_key("key")
    $redis.expects(:setex).with(key, 60 , Marshal.dump("bob"))

    cache.fetch("key", expires_in: 1.minute) do
      "bob"
    end
  end

  it "can store and fetch correctly" do
    cache.delete "key"

    r = cache.fetch "key" do
      "bob"
    end
    r.should == "bob"
  end

  it "can fetch existing correctly" do
    cache.write "key", "bill"

    r = cache.fetch "key" do
      "bob"
    end
    r.should == "bill"
  end
end
