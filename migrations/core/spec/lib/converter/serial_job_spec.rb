# frozen_string_literal: true

RSpec.describe Migrations::Converter::SerialJob do
  subject(:job) { described_class.new(step) }

  let(:step) { instance_double(Migrations::Converter::ProgressStep) }
  let(:item) { "Item" }
  let(:tracker) { instance_double(Migrations::Converter::StepTracker) }
  let(:stats) { Migrations::Converter::StepStats.new }

  before do
    allow(step).to receive(:tracker).and_return(tracker)

    allow(tracker).to receive(:reset_stats!)
    allow(tracker).to receive(:log_error)
    allow(tracker).to receive(:stats).and_return(stats)
  end

  describe "#run" do
    it "resets stats and processes item" do
      allow(step).to receive(:process_item).and_return(stats)

      result = job.run(item)
      expect(result).to eq(stats)

      expect(tracker).to have_received(:reset_stats!)
      expect(step).to have_received(:process_item).with(item)
    end

    it "logs error if processing item raises an exception" do
      allow(step).to receive(:process_item).and_raise(StandardError)

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
