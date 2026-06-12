# frozen_string_literal: true

RSpec.describe Migrations::Conversion::ConsoleReporter do
  subject(:reporter) { described_class.new }

  describe "#start_step" do
    it "prints the title on its own line" do
      expect { reporter.start_step("Fixture step") }.to output("Fixture step\n").to_stdout
    end
  end

  describe "#notice" do
    it "prints the message indented by four spaces" do
      expect { reporter.notice("Calculating took 6 seconds") }.to output(
        "    Calculating took 6 seconds\n",
      ).to_stdout
    end
  end

  describe "#with_progress" do
    it "runs the block with a progress bar created for the given max progress" do
      progressbar = instance_double(Migrations::ExtendedProgressBar)
      allow(Migrations::ExtendedProgressBar).to receive(:new).with(max_progress: 7).and_return(
        progressbar,
      )
      allow(progressbar).to receive(:run).and_yield(progressbar)

      yielded = nil
      reporter.with_progress(max_progress: 7) { |progress| yielded = progress }

      expect(yielded).to be(progressbar)
    end

    it "yields a progress object that accepts the full `update` signature" do
      progressbar = instance_double(Migrations::ExtendedProgressBar)
      allow(Migrations::ExtendedProgressBar).to receive(:new).and_return(progressbar)
      allow(progressbar).to receive(:run).and_yield(progressbar)
      allow(progressbar).to receive(:update)

      reporter.with_progress(max_progress: 2) do |progress|
        progress.update(increment_by: 1)
        progress.update(increment_by: 2, skip_count: 1, warning_count: 1, error_count: 1)
      end

      expect(progressbar).to have_received(:update).with(increment_by: 1).ordered
      expect(progressbar).to have_received(:update).with(
        increment_by: 2,
        skip_count: 1,
        warning_count: 1,
        error_count: 1,
      ).ordered
    end
  end
end
