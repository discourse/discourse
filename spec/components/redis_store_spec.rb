require 'spec_helper'
require 'cache'

describe "Redis Store" do

  let :cache do
    Cache.new(namespace: 'foo')
  end

  let :store do
    DiscourseRedis.new_redis_store
  end

  before(:each) do
    cache.redis.del "key"
    store.delete "key"
  end

  it "can store stuff" do
    store.fetch "key" do
      "key in store"
    end

    r = store.read "key"

    r.should == "key in store"
  end

  it "doesn't collide with our Cache" do

    store.fetch "key" do
      "key in store"
    end

    cache.fetch "key" do
      "key in cache"
    end

    r = store.read "key"

    r.should == "key in store"
  end

  it "can be cleared without clearing our cache" do
    store.fetch "key" do
      "key in store"
    end

    cache.fetch "key" do
      "key in cache"
    end

    store.clear
    store.read("key").should be_nil
    cache.fetch("key").should == "key in cache"

  end

end
