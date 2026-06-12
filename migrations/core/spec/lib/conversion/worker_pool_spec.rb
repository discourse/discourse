# frozen_string_literal: true

RSpec.describe Migrations::Conversion::WorkerPool do
  subject(:pool) { described_class.new(size: pool_size) }

  let(:pool_size) { 2 }
  let(:work_queue) { Queue.new }
  let(:output_queue) { Queue.new }

  after do
    work_queue.close if !work_queue.closed?
    output_queue.close if !output_queue.closed?
  end

  def create_echo_job
    job = instance_double(Migrations::Conversion::ParallelJob, setup: nil, cleanup: nil)
    allow(job).to receive(:run) { |item| { echoed: item[:id] } }
    job
  end

  def drained_output
    results = []
    results << output_queue.pop until output_queue.empty?
    results
  end

  describe "#start" do
    it "forks one worker per pool slot by default and processes all queued items" do
      allow(Migrations::ForkManager).to receive(:fork).and_call_original

      batch = pool.start(work_queue:, output_queue:) { create_echo_job }
      5.times { |id| work_queue << { id: } }
      work_queue.close
      batch.wait
      output_queue.close

      expect(Migrations::ForkManager).to have_received(:fork).exactly(pool_size).times
      expect(drained_output).to match_array(Array.new(5) { |id| { echoed: id } })
    end

    def start_empty_batch(**kwargs)
      batch = pool.start(work_queue:, output_queue:, **kwargs) { create_echo_job }
      work_queue.close
      batch.wait
      output_queue.close
    end

    it "forks a single worker when started with `size: 1`" do
      allow(Migrations::ForkManager).to receive(:fork).and_call_original

      start_empty_batch(size: 1)

      expect(Migrations::ForkManager).to have_received(:fork).once
    end

    it "clamps the requested size to the pool size" do
      allow(Migrations::ForkManager).to receive(:fork).and_call_original

      start_empty_batch(size: pool_size + 10)

      expect(Migrations::ForkManager).to have_received(:fork).exactly(pool_size).times
    end

    it "clamps the requested size to a minimum of one worker" do
      allow(Migrations::ForkManager).to receive(:fork).and_call_original

      start_empty_batch(size: 0)

      expect(Migrations::ForkManager).to have_received(:fork).once
    end

    it "runs the fork hooks once per `start` call, not once per worker" do
      before_fork_count = 0
      after_fork_count = 0
      before_fork_hook = Migrations::ForkManager.before_fork { before_fork_count += 1 }
      after_fork_hook = Migrations::ForkManager.after_fork_parent { after_fork_count += 1 }

      start_empty_batch

      expect(before_fork_count).to eq(1)
      expect(after_fork_count).to eq(1)
    ensure
      Migrations::ForkManager.remove_before_fork(before_fork_hook)
      Migrations::ForkManager.remove_after_fork_parent(after_fork_hook)
    end

    it "builds a fresh job for every worker" do
      jobs = []

      batch =
        pool.start(work_queue:, output_queue:) do
          job = create_echo_job
          jobs << job
          job
        end
      work_queue.close
      batch.wait
      output_queue.close

      expect(jobs.size).to eq(pool_size)
      expect(jobs.uniq.size).to eq(pool_size)
    end
  end

  describe "Batch#wait" do
    it "returns only after every worker process has exited" do
      Dir.mktmpdir do |dir|
        batch =
          pool.start(work_queue:, output_queue:) do
            job = instance_double(Migrations::Conversion::ParallelJob, setup: nil)
            allow(job).to receive(:cleanup) do
              File.write(File.join(dir, "worker_#{Process.pid}"), "exited")
            end
            job
          end
        work_queue.close
        batch.wait
        output_queue.close

        expect(Dir.children(dir).size).to eq(pool_size)
      end
    end
  end
end
