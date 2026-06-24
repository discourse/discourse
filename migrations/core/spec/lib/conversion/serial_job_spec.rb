# frozen_string_literal: true

RSpec.describe Migrations::Conversion::SerialJob do
  subject(:job) { described_class.new(processor) }

  let(:processor) { instance_double(Migrations::Conversion::ProgressStep::Processor) }
  let(:item) { "Item" }
  let(:tracker) { instance_double(Migrations::Conversion::StepTracker) }
  let(:stats) { Migrations::Conversion::StepStats.new }

  before do
    allow(processor).to receive(:tracker).and_return(tracker)
    allow(processor).to receive(:setup)

    allow(tracker).to receive(:reset_stats!)
    allow(tracker).to receive(:log_error)
    allow(tracker).to receive(:stats).and_return(stats)
  end

  describe "#setup" do
    it "runs the processor's `setup`" do
      job.setup
      expect(processor).to have_received(:setup)
    end

    it "raises an error when the processor writes to the IntermediateDB during `setup`" do
      allow(processor).to receive(:setup) do
        Migrations::Database::IntermediateDB.insert("INSERT INTO foo (id) VALUES (?)", 1)
      end

      expect { job.setup }.to raise_error(Migrations::Conversion::SetupGuard::SetupError)
    end
  end

  describe "#run" do
    it "resets stats and processes item" do
      allow(processor).to receive(:process).and_return(stats)

      result = job.run(item)
      expect(result).to eq(stats)

      expect(tracker).to have_received(:reset_stats!)
      expect(processor).to have_received(:process).with(item)
    end

    it "logs error if processing item raises an exception" do
      allow(processor).to receive(:process).and_raise(StandardError)

      job.run(item)

      expect(tracker).to have_received(:log_error).with(
        "Failed to process item",
        exception: an_instance_of(StandardError),
        details: item,
      )
    end
  end

  describe "#cleanup" do
    it "can be called without errors" do
      expect { job.cleanup }.not_to raise_error
    end
  end
end
