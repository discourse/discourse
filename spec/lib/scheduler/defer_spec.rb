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
    Discourse.catch_job_exceptions!
    @defer = DeferInstance.new
    @defer.async = true
  end

  after do
    @defer.stop!
    Discourse.reset_catch_job_exceptions!
  end

  it "can finish work properly without crashing" do
    @defer.later {}
    sleep 0.005
    @defer.stop!(finish_work: true)
  end

  it "supports basic instrumentation" do
    @defer.later("first") {}
    @defer.later("first") {}
    @defer.later("second") {}
    @defer.later("bad") { raise "boom" }

    @defer.stop!(finish_work: true)

    stats = Hash[@defer.stats]

    expect(stats["first"][:queued]).to eq(2)
    expect(stats["first"][:finished]).to eq(2)
    expect(stats["first"][:errors]).to eq(0)
    expect(stats["first"][:duration]).to be > 0

    expect(stats["second"][:queued]).to eq(1)
    expect(stats["second"][:finished]).to eq(1)
    expect(stats["second"][:errors]).to eq(0)
    expect(stats["second"][:duration]).to be > 0

    expect(stats["bad"][:queued]).to eq(1)
    expect(stats["bad"][:finished]).to eq(1)
    expect(stats["bad"][:duration]).to be > 0
    expect(stats["bad"][:errors]).to eq(1)
  end

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
    @defer.stop!(finish_work: true)
    expect(s).to eq("good")
  end

  describe "#later" do
    let!(:ivar) { Concurrent::IVar.new }
    let!(:responses) { Thread::Queue.new }

    def later(db, current_user, request)
      @defer.later(nil, db, current_user: current_user) do
        ivar.value
        responses.push([db, current_user, request])
      end
    end

    it "runs jobs in a fair order" do
      later("site1", 1, 1)
      later("site1", 1, 2)
      later("site1", 2, 3)
      later("site2", 3, 4)
      later("site2", 4, 5)
      later("site2", 4, 6)

      ivar.set(nil)

      result = 6.times.map { responses.shift }

      expect(result).to eq(
        [
          ["site1", 1, 1],
          ["site2", 3, 4],
          ["site1", 2, 3],
          ["site2", 4, 5],
          ["site1", 1, 2],
          ["site2", 4, 6],
        ],
      )
    end
  end
end
