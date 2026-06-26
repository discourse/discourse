# frozen_string_literal: true

RSpec.describe Migrations::Conversion::StepExecutor do
  subject(:executor) { described_class.new(step, reporter:) }

  let(:handle) { instance_double(Migrations::Reporting::Reporter::StepHandle, finish: nil) }
  let(:reporter) { instance_double(Migrations::Reporting::Plain, start_step: handle) }
  let(:step_class) { Class.new(Migrations::Conversion::Step) { title "Fixture step" } }
  let(:step) { step_class.new(settings: {}) }

  describe "#execute" do
    it "announces the step through the reporter and executes it" do
      allow(step).to receive(:execute)

      executor.execute

      expect(reporter).to have_received(:start_step).with("Fixture step")
      expect(step).to have_received(:execute)
    end

    it "finishes the step's handle even when the step fails" do
      allow(step).to receive(:execute).and_raise("boom")

      expect { executor.execute }.to raise_error("boom")
      expect(handle).to have_received(:finish)
    end
  end
end
