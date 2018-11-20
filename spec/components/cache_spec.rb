require 'rails_helper'
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
    hash = { a: 1, b: [1, 2, 3] }
    cache.write("hash", hash)
    expect(cache.read("hash")).to eq(hash)
  end

  it "can be cleared" do
    $redis.set("boo", "boo")
    cache.write("hello0", "world")
    cache.write("hello1", "world")
    cache.clear

    expect($redis.get("boo")).to eq("boo")
    expect(cache.read("hello0")).to eq(nil)
  end

  it "can delete correctly" do
    cache.fetch("key", expires_in: 1.minute) do
      "test"
    end

    cache.delete("key")
    expect(cache.fetch("key")).to eq(nil)
  end

  it "calls setex in redis" do
    cache.delete("key")
    cache.delete("bla")

    key = cache.normalize_key("key")

    cache.fetch("key", expires_in: 1.minute) do
      "bob"
    end

    expect($redis.ttl(key)).to be_within(2.seconds).of(1.minute)

    # we always expire withing a day
    cache.fetch("bla") { "hi" }

    key = cache.normalize_key("bla")
    expect($redis.ttl(key)).to be_within(2.seconds).of(1.day)
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

  it "can fetch keys with pattern" do
    cache.write "users:admins", "jeff"
    cache.write "users:moderators", "bob"

    expect(cache.keys("users:*").count).to eq(2)
  end
end
