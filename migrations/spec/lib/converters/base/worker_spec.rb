# frozen_string_literal: true

RSpec.describe ::Migrations::Converters::Base::Worker do
  subject(:worker) { described_class.new(index, input_queue, output_queue, job) }

  let(:index) { 1 }
  let(:input_queue) { Queue.new }
  let(:output_queue) { Queue.new }
  let(:job) do
    instance_double(::Migrations::Converters::Base::ParallelJob, run: "result", cleanup: nil)
  end

  after do
    input_queue.close if !input_queue.closed?
    output_queue.close if !output_queue.closed?
  end

  describe "#start" do
    it "works when `input_queue` is empty" do
      expect do
        worker.start
        input_queue.close
        worker.wait
        output_queue.close
      end.not_to raise_error
    end

    it "uses `ForkManager.fork`" do
      allow(::Migrations::ForkManager).to receive(:fork).and_call_original

      worker.start
      input_queue.close
      worker.wait
      output_queue.close

      expect(::Migrations::ForkManager).to have_received(:fork)
    end

    it "writes the output of `job.run` into `output_queue`" do
      allow(job).to receive(:run) { |data| "run: #{data[:text]}" }

      worker.start
      input_queue << { text: "Item 1" } << { text: "Item 2" } << { text: "Item 3" }
      input_queue.close
      worker.wait
      output_queue.close

      expect(output_queue).to have_queue_contents("run: Item 1", "run: Item 2", "run: Item 3")
    end

    def create_progress_stats(progress: 1, warning_count: 0, error_count: 0)
      ::Migrations::Converters::Base::StepStats.new(progress:, warning_count:, error_count:)
    end

    it "writes objects to the `output_queue`" do
      all_stats = [
        create_progress_stats,
        create_progress_stats(warning_count: 1),
        create_progress_stats(warning_count: 1, error_count: 1),
        create_progress_stats(warning_count: 2, error_count: 1),
      ]

      allow(job).to receive(:run) do |data|
        index = data[:index]
        [index, all_stats[index]]
      end

      worker.start
      input_queue << { index: 0 } << { index: 1 } << { index: 2 } << { index: 3 }
      input_queue.close
      worker.wait
      output_queue.close

      expect(output_queue).to have_queue_contents(
        [0, all_stats[0]],
        [1, all_stats[1]],
        [2, all_stats[2]],
        [3, all_stats[3]],
      )
    end

    it "runs `job.cleanup` at the end" do
      temp_file = Tempfile.new("method_call_check")
      temp_file_path = temp_file.path

      allow(job).to receive(:run) do |data|
        File.write(temp_file_path, "run: #{data[:text]}\n", mode: "a+")
        data[:text]
      end
      allow(job).to receive(:cleanup) do
        File.write(temp_file_path, "cleanup\n", mode: "a+")
      end

      worker.start
      input_queue << { text: "Item 1" } << { text: "Item 2" } << { text: "Item 3" }
      input_queue.close
      worker.wait
      output_queue.close

      expect(File.read(temp_file_path)).to eq <<~LOG
        run: Item 1
        run: Item 2
        run: Item 3
        cleanup
      LOG
    ensure
      temp_file.unlink
    end
  end
end
