require 'spec_helper'
require_dependency 'distributed_mutex'

describe DistributedMutex do
  it "allows only one mutex object to have the lock at a time" do
    m1 = DistributedMutex.new("test_mutex_key")
    m2 = DistributedMutex.new("test_mutex_key")

    m1.get_lock
    m2.got_lock.should be_false

    t = Thread.new do
      m2.get_lock
    end

    m1.release_lock
    t.join
    m2.got_lock.should == true
  end

  it "synchronizes correctly" do
    array = []
    t = Thread.new do
      DistributedMutex.new("correct_sync").synchronize do
        sleep 0.01
        array.push 1
      end
    end
    sleep 0.005
    DistributedMutex.new("correct_sync").synchronize do
      array.push 2
    end
    t.join
    array.should == [1, 2]
  end
end
