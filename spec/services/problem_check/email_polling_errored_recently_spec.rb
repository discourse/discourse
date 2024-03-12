# frozen_string_literal: true

RSpec.describe ProblemCheck::EmailPollingErroredRecently do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Jobs::PollMailbox.stubs(errors_in_past_24_hours: error_count) }

    context "when number of failing jobs is 0" do
      let(:error_count) { 0 }

      it { expect(check.call).to be_empty }
    end

    context "when jobs are failing" do
      let(:error_count) { 1 }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end
