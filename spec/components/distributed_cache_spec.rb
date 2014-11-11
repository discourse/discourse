require 'spec_helper'
require 'distributed_cache'

describe DistributedCache do

  def wait_for(&blk)
    i = 0
    result = false
    while !result && i < 300
      result = blk.call
      i += 1
      sleep 0.001
    end

    result.should == true
  end

  let! :cache1 do
    DistributedCache.new("test")
  end

  let! :cache2 do
    DistributedCache.new("test")
  end

  it 'allows coerces symbol keys to strings' do
    cache1[:key] = "test"
    cache1["key"].should == "test"

    wait_for do
      cache2[:key] == "test"
    end
    cache2["key"].should == "test"
  end

  it 'sets other caches' do
    cache1["test"] = "world"
    wait_for do
      cache2["test"] == "world"
    end
  end

  it 'deletes from other caches' do
    cache1["foo"] = "bar"

    wait_for do
      cache2["foo"] == "bar"
    end

    cache1.delete("foo")
    cache1["foo"].should == nil

    wait_for do
      cache2["foo"] == nil
    end
  end

  it 'clears cache on request' do
    cache1["foo"] = "bar"

    wait_for do
      cache2["foo"] == "bar"
    end

    cache1.clear
    cache1["foo"].should == nil
    wait_for do
      cache2["boom"] == nil
    end
  end

end
