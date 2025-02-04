# frozen_string_literal: true

RSpec.describe ::Migrations::Converters::Base::ParallelJob do
  subject(:job) { described_class.new(step) }

  let(:step) { instance_double(::Migrations::Converters::Base::ProgressStep) }
  let(:item) { { key: "value" } }
  let(:tracker) { instance_double(::Migrations::Converters::Base::StepTracker) }
  let(:stats) { ::Migrations::Converters::Base::StepStats.new }
  let(:intermediate_db) { class_double(::Migrations::Database::IntermediateDB).as_stubbed_const }

  before do
    allow(step).to receive(:tracker).and_return(tracker)

    allow(tracker).to receive(:reset_stats!)
    allow(tracker).to receive(:log_error)
    allow(tracker).to receive(:stats).and_return(stats)

    allow(intermediate_db).to receive(:setup)
    allow(intermediate_db).to receive(:close)
  end

  after do
    ::Migrations::Database::IntermediateDB.setup(nil)
    ::Migrations::ForkManager.clear!
  end

  describe "#initialize" do
    it "sets up `OfflineConnection` as `IntermediateDB` connection" do
      described_class.new(step)

      ::Migrations::ForkManager.fork do
        expect(intermediate_db).to have_received(:setup).with(
          an_instance_of(::Migrations::Database::OfflineConnection),
        )
      end
    end
  end

  describe "#run" do
    let(:offline_connection) { instance_double(::Migrations::Database::OfflineConnection) }

    before do
      allow(::Migrations::Database::OfflineConnection).to receive(:new).and_return(
        offline_connection,
      )
      allow(offline_connection).to receive(:clear!)

      allow(step).to receive(:process_item)
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
      allow(step).to receive(:process_item).and_raise(StandardError.new("error"))

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
