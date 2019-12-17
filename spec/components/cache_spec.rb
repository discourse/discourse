# frozen_string_literal: true

require 'rails_helper'
require 'cache'

describe Cache do

  let :cache do
    Cache.new
  end

  it "supports exist?" do
    cache.write("testing", 1.1)
    expect(cache.exist?("testing")).to eq(true)
    expect(cache.exist?(SecureRandom.hex)).to eq(false)
  end

  it "supports float" do
    cache.write("float", 1.1)
    expect(cache.read("float")).to eq(1.1)
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
    Discourse.redis.set("boo", "boo")
    cache.write("hello0", "world")
    cache.write("hello1", "world")
    cache.clear

    expect(Discourse.redis.get("boo")).to eq("boo")
    expect(cache.read("hello0")).to eq(nil)
  end

  it "can delete correctly" do
    cache.delete("key")

    cache.fetch("key", expires_in: 1.minute) do
      "test"
    end

    expect(cache.fetch("key")).to eq("test")

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

    expect(Discourse.redis.ttl(key)).to be_within(2.seconds).of(1.minute)

    # we always expire withing a day
    cache.fetch("bla") { "hi" }

    key = cache.normalize_key("bla")
    expect(Discourse.redis.ttl(key)).to be_within(2.seconds).of(1.day)
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
