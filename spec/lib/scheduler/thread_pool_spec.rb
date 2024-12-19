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

  describe "initialization" do
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

    it "scales up threads when work increases" do
      completion_queue = Queue.new
      blocker_queue = Queue.new

      # Create enough blocking tasks to force thread creation
      (max_threads + 1).times do |i|
        pool.post do
          completion_queue << i
          blocker_queue.pop
        end
      end

      # we spin up threads in the thread loop, so it can take
      # a bit of time to react to work pressure
      wait_for { pool.stats[:thread_count] == max_threads }

      expect(pool.stats[:thread_count]).to eq(max_threads)

      (max_threads + 1).times { blocker_queue << :continue }

      results = Array.new(max_threads + 1) { completion_queue.pop }

      expect(results.sort).to eq((0..max_threads).to_a)
    end
  end

  describe "#shutdown" do
    it "prevents new tasks from being posted" do
      completion_queue = Queue.new
      pool.post { completion_queue << 1 }
      completion_queue.pop # ensure first task completes

      pool.shutdown
      expect(pool.shutdown?).to be true
      expect { pool.post { true } }.to raise_error(Scheduler::ThreadPool::ShutdownError)
    end

    it "completes pending tasks before shutting down" do
      blocker_queue1 = Queue.new
      completion_queue1 = Queue.new

      blocker_queue2 = Queue.new
      completion_queue2 = Queue.new

      3.times do |i|
        pool.post do
          blocker_queue1.pop
          completion_queue1 << i
          blocker_queue2.pop
          completion_queue2 << i
        end
      end

      3.times { blocker_queue1 << :continue }
      results1 = Array.new(3) { completion_queue1.pop }

      # this is not perfect, but it close enough
      # usually spawing the thread will take longer than making the call to shutdown
      # even if it does not it does not really matter that much
      results2 = nil

      Thread.new do
        3.times { blocker_queue2 << :continue }
        results2 = Array.new(3) { completion_queue2.pop }
      end

      pool.shutdown
      pool.wait_for_termination(timeout: 1)

      expect(results1.size).to eq(3)
      expect(results1.sort).to eq([0, 1, 2])

      expect(results2.size).to eq(3)
      expect(results2.sort).to eq([0, 1, 2])
    end
  end

  describe "error handling" do
    it "captures and logs exceptions without crashing the thread" do
      completion_queue = Queue.new
      error_msg = "Test error"

      pool.post { raise StandardError, error_msg }
      pool.post { completion_queue << :completed }

      # If the error handling works, this second task should complete
      expect(completion_queue.pop).to eq(:completed)
      expect(pool.stats[:thread_count]).to eq(min_threads)
    end
  end

  describe "queue management" do
    it "processes tasks in FIFO order" do
      completion_queue = Queue.new
      control_queue = Queue.new

      # First task will wait for signal
      pool.post do
        control_queue.pop
        completion_queue << 1
      end

      # Second task should execute after first
      pool.post { completion_queue << 2 }

      # Signal first task to complete
      control_queue << :continue

      results = Array.new(2) { completion_queue.pop }
      expect(results).to eq([1, 2])
    end
  end

  describe "when thread pool has zero min threads" do
    it "can quickly process tasks" do
      # setting idle time to 1000 to ensure that there are maximal delays waiting
      # for jobs
      pool = Scheduler::ThreadPool.new(min_threads: 0, max_threads: 5, idle_time: 1000)

      done = Queue.new
      pool.post { done << :done }

      # should happen in less than 1 second
      Timeout.timeout(1) { expect(done.pop).to eq(:done) }

      pool.shutdown
      pool.wait_for_termination
      expect(pool.stats[:thread_count]).to eq(0)
    end
  end

  describe "stress test" do
    it "handles multiple task submissions correctly" do
      completion_queue = Queue.new
      task_count = 50

      task_count.times { |i| pool.post { completion_queue << i } }

      results = Array.new(task_count) { completion_queue.pop }
      expect(results.sort).to eq((0...task_count).to_a)
    end
  end
end
