require 'rails_helper'
require 'distributed_cache'

describe DistributedCache do

  let! :cache1 do
    DistributedCache.new("test")
  end

  let! :cache2 do
    DistributedCache.new("test")
  end

  it 'allows us to store Set' do
    c1 = DistributedCache.new("test1")
    c2 = DistributedCache.new("test1")

    set = Set.new
    set << 1
    set << "b"
    set << 92803984
    set << 93739739873973

    c1["cats"] = set

    wait_for do
      c2["cats"] == set
    end

    expect(c2["cats"]).to eq(set)

    set << 5

    c2["cats"] == set

    wait_for do
      c1["cats"] == set
    end

    expect(c1["cats"]).to eq(set)
  end

  it 'does not leak state across caches' do
    c2 = DistributedCache.new("test1")
    c3 = DistributedCache.new("test1")
    c2["hi"] = "hi"
    wait_for do
      c3["hi"] == "hi"
    end

    Thread.pass
    expect(cache1["hi"]).to eq(nil)

  end

  it 'allows coerces symbol keys to strings' do
    cache1[:key] = "test"
    expect(cache1["key"]).to eq("test")

    wait_for do
      cache2[:key] == "test"
    end
    expect(cache2["key"]).to eq("test")
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
    expect(cache1["foo"]).to eq(nil)

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
    expect(cache1["foo"]).to eq(nil)
    wait_for do
      cache2["boom"] == nil
    end
  end

end
