# frozen_string_literal: true

RSpec.describe Migrations::Conversion::StepExecutor do
  subject(:executor) { described_class.new(step, reporter:) }

  let(:reporter) { Migrations::Conversion::ConsoleReporter.new }
  let(:step_class) { Class.new(Migrations::Conversion::Step) { title "Fixture step" } }
  let(:step) { step_class.new(settings: {}) }

  describe "#execute" do
    it "announces the step through the reporter and executes it" do
      allow(step).to receive(:execute)

      expect { executor.execute }.to output("Fixture step\n").to_stdout
      expect(step).to have_received(:execute)
    end

    it "reports the end of the step even when the step fails" do
      reporter =
        instance_double(Migrations::Conversion::ConsoleReporter, start_step: nil, finish_step: nil)
      executor = described_class.new(step, reporter:)
      allow(step).to receive(:execute).and_raise("boom")

      expect { executor.execute }.to raise_error("boom")
      expect(reporter).to have_received(:finish_step).with("Fixture step")
    end
  end
end
