require 'spec_helper'
require 'cache'

describe Cache do

  let :cache do
    Cache.new
  end

  it "supports fixnum" do
    cache.write("num", 1)
    expect(cache.read("num")).to eq(1)
  end

  it "supports hash" do
    hash = {a: 1, b: [1,2,3]}
    cache.write("hash", hash)
    expect(cache.read("hash")).to eq(hash)
  end

  it "can be cleared" do
    cache.write("hello0", "world")
    cache.write("hello1", "world")
    cache.clear

    expect(cache.read("hello0")).to eq(nil)
  end

  it "can delete by family" do
    cache.write("key2", "test", family: "my_family")
    cache.write("key", "test", expires_in: 1.minute, family: "my_family")

    cache.delete_by_family("my_family")

    expect(cache.fetch("key")).to eq(nil)
    expect(cache.fetch("key2")).to eq(nil)

  end

  it "can delete correctly" do
    cache.fetch("key", expires_in: 1.minute) do
      "test"
    end

    cache.delete("key")
    expect(cache.fetch("key")).to eq(nil)
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
    expect(r).to eq("bob")
  end

  it "can fetch existing correctly" do
    cache.write "key", "bill"

    r = cache.fetch "key" do
      "bob"
    end
    expect(r).to eq("bill")
  end
end
