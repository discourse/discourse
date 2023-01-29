# frozen_string_literal: true

RSpec.describe DistributedMemoizer do
  after do
    Discourse.redis.del(DistributedMemoizer.redis_key("hello"))
    Discourse.redis.del(DistributedMemoizer.redis_lock_key("hello"))
  end

  def memoize(&block)
    DistributedMemoizer.memoize("hello", duration = 120, &block)
  end

  it "returns the value of a block" do
    expect(memoize { "abc" }).to eq("abc")
  end

  it "return the old value once memoized" do
    memoize { "abc" }

    expect(memoize { "world" }).to eq("abc")
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
