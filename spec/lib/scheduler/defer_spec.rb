# encoding: utf-8
# frozen_string_literal: true

RSpec.describe Scheduler::Defer do
  class DeferInstance
    include Scheduler::Deferrable
  end

  def wait_for(timeout, &blk)
    till = Time.now + (timeout.to_f / 1000)
    sleep 0.001 while Time.now < till && !blk.call
  end

  before do
    @defer = DeferInstance.new
    @defer.async = true
  end

  after { @defer.stop! }

  it "supports timeout reporting" do
    @defer.timeout = 0.05

    logger =
      track_log_messages do |l|
        10.times { @defer.later("fast job") {} }

        @defer.later "weird slow job" do
          sleep
        end

        wait_for(200) { l.errors.length == 1 }
      end

    expect(logger.warnings.length).to eq(0)
    expect(logger.fatals.length).to eq(0)
    expect(logger.errors.length).to eq(1)
    expect(logger.errors).to include(/'weird slow job' is still running/)
  end

  it "can pause and resume" do
    x = 1
    @defer.pause

    @defer.later { x = 2 }

    expect(@defer.length).to eq(1)

    @defer.do_all_work

    expect(x).to eq(2)

    @defer.resume

    @defer.later { x = 3 }

    wait_for(1000) { x == 3 }

    expect(x).to eq(3)
  end

  it "recovers from a crash / fork" do
    s = nil
    @defer.stop!
    wait_for(1000) { @defer.stopped? }
    # hack allow thread to die
    sleep 0.005

    @defer.later { s = "good" }

    wait_for(1000) { s == "good" }

    expect(s).to eq("good")
  end

  it "can queue jobs properly" do
    s = nil

    @defer.later { s = "good" }

    wait_for(1000) { s == "good" }

    expect(s).to eq("good")
  end
end
