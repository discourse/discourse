# frozen_string_literal: true

RSpec.describe ProblemCheck::EmailPollingErroredRecently do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Jobs::PollMailbox.stubs(errors_in_past_24_hours: error_count) }

    context "when number of failing jobs is 0" do
      let(:error_count) { 0 }

      it { expect(check).to be_chill_about_it }
    end

    context "when jobs are failing" do
      let(:error_count) { 1 }

      it do
        expect(check).to(
          have_a_problem.with_priority("low").with_message(
            "Email polling has generated an error in the past 24 hours. Look at <a href='/logs' target='_blank'>the logs</a> for more details.",
          ),
        )
      end
    end
  end
end
