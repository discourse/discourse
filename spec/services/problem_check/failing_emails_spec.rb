# frozen_string_literal: true

RSpec.describe ProblemCheck::FailingEmails do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Jobs.stubs(num_email_retry_jobs: failing_jobs) }

    context "when number of failing jobs is 0" do
      let(:failing_jobs) { 0 }

      it { expect(check.call).to be_empty }
    end

    context "when jobs are failing" do
      let(:failing_jobs) { 1 }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end
