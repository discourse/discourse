# frozen_string_literal: true

RSpec.describe Migrations::Conversion::ParallelJob do
  subject(:job) { described_class.new(processor) }

  let(:processor) { instance_double(Migrations::Conversion::ProgressStep::Processor) }
  let(:item) { { key: "value" } }
  let(:tracker) { instance_double(Migrations::Conversion::StepTracker) }
  let(:stats) { Migrations::Conversion::StepStats.new }
  let(:intermediate_db) { class_double(Migrations::Database::IntermediateDB).as_stubbed_const }

  before do
    allow(processor).to receive(:tracker).and_return(tracker)
    allow(processor).to receive(:setup)

    allow(tracker).to receive(:reset_stats!)
    allow(tracker).to receive(:log_error)
    allow(tracker).to receive(:stats).and_return(stats)

    allow(intermediate_db).to receive(:setup)
    allow(intermediate_db).to receive(:with_connection).and_yield
    allow(intermediate_db).to receive(:close)
  end

  describe "#setup" do
    it "sets up `OfflineConnection` as `IntermediateDB` connection" do
      job.setup

      expect(intermediate_db).to have_received(:setup).with(
        an_instance_of(Migrations::Database::OfflineConnection),
      )
    end

    it "runs the framework setup before the processor's `setup`" do
      job.setup

      expect(intermediate_db).to have_received(:setup).ordered
      expect(processor).to have_received(:setup).ordered
    end

    it "runs the processor's `setup` through the setup guard" do
      job.setup

      expect(intermediate_db).to have_received(:with_connection).with(
        an_instance_of(Migrations::Conversion::SetupGuard::NoWriteConnection),
      )
      expect(processor).to have_received(:setup)
    end
  end

  describe "#run" do
    let(:offline_connection) { instance_double(Migrations::Database::OfflineConnection) }

    before do
      allow(Migrations::Database::OfflineConnection).to receive(:new).and_return(offline_connection)
      allow(offline_connection).to receive(:clear!)

      allow(processor).to receive(:process)
      allow(offline_connection).to receive(:parametrized_insert_statements).and_return(
        [["SQL", [1, 2]], ["SQL", [2, 3]]],
      )
    end

    it "resets stats and clears the offline connection" do
      job.run(item)

      expect(tracker).to have_received(:reset_stats!)
      expect(offline_connection).to have_received(:clear!)
    end

    it "processes an item and logs errors if exceptions occur" do
      allow(processor).to receive(:process).and_raise(StandardError.new("error"))

      job.run(item)

      expect(tracker).to have_received(:log_error).with(
        "Failed to process item",
        exception: an_instance_of(StandardError),
        details: item,
      )
    end

    it "returns the parametrized insert statements and stats" do
      result = job.run(item)

      expect(result).to eq([[["SQL", [1, 2]], ["SQL", [2, 3]]], stats])
    end
  end

  describe "#cleanup" do
    it "can be called without errors" do
      expect { job.cleanup }.not_to raise_error
    end
  end
end
