# frozen_string_literal: true

RSpec.describe Discourse::ForkBarrier do
  let(:pool) { Scheduler::ThreadPool.new(min_threads: 0, max_threads: 1) }

  after do
    described_class.resume
    pool.shutdown
    pool.wait_for_termination(timeout: 5)
  end

  describe ".drain" do
    it "finishes deferred work that waits for pool results" do
      original_async = Scheduler::Defer.async
      Scheduler::Defer.async = true
      result = Queue.new
      completed = Queue.new
      Scheduler::Defer.later do
        pool.post { result << :query }
        completed << result.pop
      end

      described_class.drain

      expect(completed.pop(timeout: 5)).to eq(:query)
      expect(Scheduler::Defer.length).to eq(0)
      expect(pool.idle?).to eq(true)
    ensure
      described_class.resume
      Scheduler::Defer.stop!(finish_work: true)
      Scheduler::Defer.async = original_async
    end

    it "finishes deferred work submitted by a running pool task" do
      original_async = Scheduler::Defer.async
      Scheduler::Defer.async = true
      completed = Queue.new
      pool.post { Scheduler::Defer.later { completed << :deferred } }

      described_class.drain

      expect(completed.pop(timeout: 5)).to eq(:deferred)
      expect(Scheduler::Defer.length).to eq(0)
    ensure
      described_class.resume
      Scheduler::Defer.stop!(finish_work: true)
      Scheduler::Defer.async = original_async
    end

    it "keeps fork preparations exclusive" do
      entered = Queue.new
      described_class.drain
      contender =
        Thread.new do
          described_class.drain
          entered << true
          described_class.resume
        end
      expect(entered.pop(timeout: 0.1)).to eq(nil)

      described_class.resume

      expect(entered.pop(timeout: 5)).to eq(true)
      expect(contender.join(5)).to eq(contender)
    ensure
      described_class.resume
      contender&.join(5)
    end
  end

  describe ".wait_for_idle" do
    it "preserves running and queued work when the deadline expires" do
      started = Queue.new
      release = Queue.new
      completed = Queue.new
      pool.post do
        started << true
        release.pop
        completed << :running
      end
      expect(started.pop(timeout: 5)).to eq(true)
      pool.post { completed << :queued }

      expect(described_class.wait_for_idle(timeout: 0)).to eq(false)

      pool.post { completed << :new }
      release << true
      expect(3.times.map { completed.pop(timeout: 5) }).to eq(%i[running queued new])
      expect(described_class.wait_for_idle(timeout: 5)).to eq(true)
    ensure
      release&.push(true)
    end
  end

  describe ".reset_after_fork" do
    it "preserves work already submitted in the current process" do
      started = Queue.new
      release = Queue.new
      pool.post do
        started << true
        release.pop
      end
      expect(started.pop(timeout: 5)).to eq(true)

      described_class.reset_after_fork

      expect(described_class.wait_for_idle(timeout: 0)).to eq(false)
      release << true
      expect(described_class.wait_for_idle(timeout: 5)).to eq(true)
    ensure
      release&.push(true)
    end
  end

  describe ".resume" do
    it "reopens admission after the fork owner exits" do
      owner = Thread.new { described_class.drain }
      expect(owner.join(5)).to eq(owner)
      completed = Queue.new

      described_class.resume
      pool.post { completed << :completed }

      expect(completed.pop(timeout: 5)).to eq(:completed)
    ensure
      owner&.join(5)
    end

    it "admits new tasks after a successful drain" do
      completed = Queue.new
      submitting = Queue.new
      described_class.drain
      producer =
        Thread.new do
          described_class.resume
          submitting << true
          pool.post { completed << :completed }
        end
      expect(submitting.pop(timeout: 5)).to eq(true)
      expect(completed.pop(timeout: 0.1)).to eq(nil)

      described_class.resume

      expect(completed.pop(timeout: 5)).to eq(:completed)
      expect(producer.join(5)).to eq(producer)
    ensure
      described_class.resume
      producer&.join(5)
    end
  end
end
