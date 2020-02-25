# frozen_string_literal: true

require 'rails_helper'

describe DistributedMemoizer do

  before do
    Discourse.redis.del(DistributedMemoizer.redis_key("hello"))
    Discourse.redis.del(DistributedMemoizer.redis_lock_key("hello"))
    Discourse.redis.unwatch
  end

  # NOTE we could use a mock redis here, but I think it makes sense to test the real thing
  # let(:mock_redis) { MockRedis.new }

  def memoize(&block)
    DistributedMemoizer.memoize("hello", duration = 120, &block)
  end

  it "returns the value of a block" do
    expect(memoize do
      "abc"
    end).to eq("abc")
  end

  it "return the old value once memoized" do

    memoize do
      "abc"
    end

    expect(memoize do
      "world"
    end).to eq("abc")
  end

  it "memoizes correctly when used concurrently" do
    results = []
    threads = []

    5.times do
      threads << Thread.new do
        results << memoize do
          sleep 0.001
          SecureRandom.hex
        end
      end
    end

    threads.each(&:join)
    expect(results.uniq.length).to eq(1)
    expect(results.count).to eq(5)

  end

end
