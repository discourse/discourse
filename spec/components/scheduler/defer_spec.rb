# encoding: utf-8
require 'spec_helper'
require 'scheduler/scheduler'

describe Scheduler::Defer do
  class DeferInstance
    include Scheduler::Deferrable
  end

  def wait_for(timeout, &blk)
    till = Time.now + (timeout.to_f / 1000)
    while Time.now < till && !blk.call
      sleep 0.001
    end
  end

  before do
    @defer = DeferInstance.new
    @defer.async = true
  end

  after do
    @defer.stop!
  end

  it "recovers from a crash / fork" do
    s = nil
    @defer.stop!
    wait_for(10) do
      @defer.stopped?
    end
    # hack allow thread to die
    sleep 0.005

    @defer.later do
      s = "good"
    end

    wait_for(10) do
      s == "good"
    end

    s.should == "good"
  end

  it "can queue jobs properly" do
    s = nil

    @defer.later do
      s = "good"
    end

    wait_for(10) do
      s == "good"
    end

    s.should == "good"
  end

end
