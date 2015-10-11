require 'rails_helper'
require_dependency 'distributed_mutex'

describe DistributedMutex do
  it "allows only one mutex object to have the lock at a time" do
    mutexes = (1..10).map do
      DistributedMutex.new("test_mutex_key")
    end

    x = 0
    mutexes.map do |m|
      Thread.new do
        m.synchronize do
          y = x
          sleep 0.001
          x = y + 1
        end
      end
    end.map(&:join)

    expect(x).to eq(10)
  end

  it "handles auto cleanup correctly" do
    m = DistributedMutex.new("test_mutex_key")

    $redis.setnx "test_mutex_key", Time.now.to_i - 1


    start = Time.now.to_i
    m.synchronize do
      "nop"
    end

    # no longer than a second
    expect(Time.now.to_i).to be <= start + 1
  end

  it "maintains mutex semantics" do
    m = DistributedMutex.new("test_mutex_key")

    expect {
      m.synchronize do
        m.synchronize{}
      end
    }.to raise_error(ThreadError)
  end

end
