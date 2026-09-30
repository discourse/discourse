# frozen_string_literal: true

RSpec.describe Scheduler::ThreadPool, type: :multisite do
  let(:min_threads) { 2 }
  let(:max_threads) { 4 }
  let(:idle_time) { 0.1 }

  let(:pool) do
    described_class.new(min_threads: min_threads, max_threads: max_threads, idle_time: idle_time)
  end

  after do
    pool.shutdown
    pool.wait_for_termination(timeout: 1)
  end

  describe "#initialize" do
    it "creates the minimum number of threads and validates parameters" do
      expect(pool.stats[:thread_count]).to eq(min_threads)
      expect(pool.stats[:min_threads]).to eq(min_threads)
      expect(pool.stats[:max_threads]).to eq(max_threads)
      expect(pool.stats[:shutdown]).to be false
    end

    it "raises ArgumentError for invalid parameters" do
      expect { described_class.new(min_threads: -1, max_threads: 2, idle_time: 1) }.to raise_error(
        ArgumentError,
        "min_threads must be 0 or larger",
      )

      expect { described_class.new(min_threads: 2, max_threads: 1, idle_time: 1) }.to raise_error(
        ArgumentError,
        "max_threads must be >= min_threads",
      )

      expect { described_class.new(min_threads: 1, max_threads: 2, idle_time: 0) }.to raise_error(
        ArgumentError,
        "idle_time must be positive",
      )
    end
  end

  describe "#post" do
    it "starts new threads after a fork without running the parent's queued tasks" do
      completed = Queue.new
      pool.pause
      pool.post { completed << :parent }

      child =
        fork do
          pool.post { completed << :child }
          exit!(completed.pop(timeout: 5) == :child ? 0 : 1)
        end
      _, status = Process.wait2(child)
      child = nil

      expect(status).to be_success
      pool.resume
      expect(completed.pop(timeout: 5)).to eq(:parent)
    ensure
      pool.resume
      if child
        begin
          Process.kill("KILL", child)
          Process.waitpid(child)
        rescue Errno::ESRCH, Errno::ECHILD
        end
      end
    end

    it "executes submitted tasks" do
      completion_queue = Queue.new

      pool.post { completion_queue << 1 }
      pool.post { completion_queue << 2 }

      results = Array.new(2) { completion_queue.pop }
      expect(results).to contain_exactly(1, 2)
    end

    it "maintains database connection context" do
      completion_queue = Queue.new

      test_multisite_connection("second") do
        pool.post { completion_queue << RailsMultisite::ConnectionManagement.current_db }
      end

      expect(completion_queue.pop).to eq("second")
    end

    it "maintains the posting thread's locale" do
      completion_queue = Queue.new

      I18n.with_locale(:fr) { pool.post { completion_queue << I18n.locale } }

      expect(completion_queue.pop).to eq(:fr)
    end

    it "scales up threads when work increases" do
      completion_queue = Queue.new
      blocker_queue = Queue.new

      (max_threads + 1).times do |index|
        pool.post do
          completion_queue << index
          blocker_queue.pop
        end
      end

      wait_for { pool.stats[:thread_count] == max_threads }

      expect(pool.stats[:thread_count]).to eq(max_threads)

      (max_threads + 1).times { blocker_queue << :continue }

      results = Array.new(max_threads + 1) { completion_queue.pop }

      expect(results.sort).to eq((0..max_threads).to_a)
    end

    it "captures and logs exceptions without crashing the thread" do
      completion_queue = Queue.new
      error_msg = "Test error"

      pool.post { raise StandardError, error_msg }
      pool.post { completion_queue << :completed }

      expect(completion_queue.pop).to eq(:completed)
      expect(pool.stats[:thread_count]).to eq(min_threads)
    end

    it "handles multiple task submissions correctly" do
      completion_queue = Queue.new
      task_count = 50

      task_count.times { |index| pool.post { completion_queue << index } }

      results = Array.new(task_count) { completion_queue.pop }
      expect(results.sort).to eq((0...task_count).to_a)
    end

    context "with one worker thread" do
      let(:min_threads) { 1 }
      let(:max_threads) { 1 }

      it "processes tasks in FIFO order" do
        completion_queue = Queue.new
        control_queue = Queue.new

        pool.post do
          control_queue.pop
          completion_queue << 1
        end

        pool.post { completion_queue << 2 }

        control_queue << :continue

        results = Array.new(2) { completion_queue.pop }
        expect(results).to eq([1, 2])
      end
    end

    context "with no minimum threads" do
      let(:min_threads) { 0 }
      let(:idle_time) { 1000 }

      it "starts processing without waiting for the idle timeout" do
        completed = Queue.new

        pool.post { completed << :completed }

        expect(completed.pop(timeout: 1)).to eq(:completed)
      end
    end
  end

  describe "#shutdown" do
    it "rejects new tasks after shutdown" do
      pool.shutdown

      expect { pool.post {} }.to raise_error(Scheduler::ThreadPool::ShutdownError)
    end

    it "finishes running and queued tasks before terminating" do
      started = Queue.new
      release = Queue.new
      completed = Queue.new
      pool.post do
        started << true
        release.pop
        completed << 0
      end
      expect(started.pop(timeout: 5)).to eq(true)
      pool.pause
      3.times { |index| pool.post { completed << index + 1 } }

      pool.shutdown
      expect(3.times.map { completed.pop(timeout: 5) }.sort).to eq([1, 2, 3])
      release << true
      pool.wait_for_termination(timeout: 5)

      expect(completed.pop(timeout: 5)).to eq(0)
      expect(pool.stats[:thread_count]).to eq(0)
    ensure
      release << true
    end
  end

  describe "#idle?" do
    it "is false while a task is running" do
      started = Queue.new
      release = Queue.new
      pool.post do
        started << true
        release.pop
      end
      expect(started.pop(timeout: 5)).to eq(true)

      expect(pool.idle?).to eq(false)
    ensure
      release << true
    end

    it "is false while tasks are queued" do
      pool.pause
      pool.post {}

      expect(pool.idle?).to eq(false)
    ensure
      pool.resume
    end
  end

  describe ".wait_for_idle" do
    it "returns false when running tasks exceed the deadline" do
      started = Queue.new
      release = Queue.new
      pool.post do
        started << true
        release.pop
      end
      expect(started.pop(timeout: 5)).to eq(true)

      expect(described_class.wait_for_idle(timeout: 0.05)).to eq(false)
    ensure
      release << true
    end

    it "returns true once queued tasks finish" do
      pool.post {}

      expect(described_class.wait_for_idle(timeout: 5)).to eq(true)
      expect(pool.idle?).to eq(true)
    end
  end

  describe ".pause" do
    after { described_class.resume }

    it "waits for running tasks to finish" do
      started = Queue.new
      release = Queue.new
      completed = Queue.new
      pool.post do
        started << true
        release.pop
        completed << :completed
      end
      expect(started.pop(timeout: 5)).to eq(true)

      pausing = Thread.new { described_class.pause }
      expect(pausing.join(0.1)).to eq(nil)
      release << true

      expect(pausing.join(5)).to eq(pausing)
      expect(completed.pop(timeout: 5)).to eq(:completed)
    ensure
      release << true
      pausing&.join(5)
    end

    it "allows shutdown while paused" do
      described_class.pause

      pool.shutdown

      expect { pool.wait_for_termination(timeout: 5) }.not_to raise_error
    end
  end

  describe ".resume" do
    after { described_class.resume }

    it "runs tasks queued while paused" do
      completed = Queue.new
      described_class.pause
      pool.post { completed << :completed }
      expect(completed.pop(timeout: 0.1)).to eq(nil)

      described_class.resume

      expect(completed.pop(timeout: 5)).to eq(:completed)
    end
  end
end
