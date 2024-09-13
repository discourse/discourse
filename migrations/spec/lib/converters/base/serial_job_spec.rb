# frozen_string_literal: true

RSpec.describe ::Migrations::Converters::Base::SerialJob do
  subject(:job) { described_class.new(step) }

  let(:step) { instance_double(::Migrations::Converters::Base::ProgressStep) }
  let(:item) { "Item" }
  let(:stats) do
    instance_double(::Migrations::Converters::Base::ProgressStats, reset!: nil, log_error: nil)
  end

  before { allow(::Migrations::Converters::Base::ProgressStats).to receive(:new).and_return(stats) }

  describe "#run" do
    it "resets stats and processes item" do
      allow(step).to receive(:process_item).and_return(stats)

      job.run(item)

      expect(stats).to have_received(:reset!)
      expect(step).to have_received(:process_item).with(item, stats)
    end

    it "logs error if processing item raises an exception" do
      allow(step).to receive(:process_item).and_raise(StandardError)

      job.run(item)

      expect(stats).to have_received(:log_error).with(
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
