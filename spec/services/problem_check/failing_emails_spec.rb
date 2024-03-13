# frozen_string_literal: true

RSpec.describe ProblemCheck::FailingEmails do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Jobs.stubs(num_email_retry_jobs: failing_jobs) }

    context "when number of failing jobs is 0" do
      let(:failing_jobs) { 0 }

      it { expect(check).to be_chill_about_it }
    end

    context "when jobs are failing" do
      let(:failing_jobs) { 1 }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          'There are 1 email jobs that failed. Check your app.yml and ensure that the mail server settings are correct. <a href="/sidekiq/retries" target="_blank">See the failed jobs in Sidekiq</a>.',
        )
      end
    end
  end
end
