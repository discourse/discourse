require 'spec_helper'
require 'cache'

describe Cache do

  let :cache do
    Cache.new
  end

  it "can delete by family" do
    cache.fetch("key2", family: "my_family") do
      "test"
    end

    cache.fetch("key", expires_in: 1.minute, family: "my_family") do
      "test"
    end

    cache.delete_by_family("my_family")
    cache.fetch("key").should be_nil
    cache.fetch("key2").should be_nil

  end

  it "can delete correctly" do
    r = cache.fetch("key", expires_in: 1.minute) do
      "test"
    end

    cache.delete("key")
    cache.fetch("key").should be_nil
  end

  it "can store with expiry correctly" do
    $redis.expects(:get).with("key").returns nil
    $redis.expects(:setex).with("key", 60 , "bob")

    r = cache.fetch("key", expires_in: 1.minute) do
      "bob"
    end
    r.should == "bob"
  end

  it "can store and fetch correctly" do
    $redis.expects(:get).with("key").returns nil
    $redis.expects(:set).with("key", "bob")

    r = cache.fetch "key" do
      "bob"
    end
    r.should == "bob"
  end

  it "can fetch existing correctly" do

    $redis.expects(:get).with("key").returns "bill"

    r = cache.fetch "key" do
      "bob"
    end
    r.should == "bill"
  end
end
