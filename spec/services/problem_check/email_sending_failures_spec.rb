# frozen_string_literal: true

RSpec.describe ProblemCheck::EmailSendingFailures do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Jobs.stubs(num_email_retry_jobs: retry_jobs) }

    let(:retry_jobs) { 0 }

    context "when there are no recent custom skipped email logs" do
      fab!(:old_failure) do
        Fabricate(
          :skipped_email_log,
          reason_type: SkippedEmailLog.reason_types[:custom],
          custom_reason: "smtp failed",
          created_at: 25.hours.ago,
        )
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when there is a recent custom skipped email log" do
      fab!(:recent_failure) do
        Fabricate(
          :skipped_email_log,
          reason_type: SkippedEmailLog.reason_types[:custom],
          custom_reason: "smtp failed",
          created_at: 1.hour.ago,
        )
      end

      it do
        expect(check).to(
          have_a_problem.with_priority("low").with_message(
            "Email sending has failed once in the past 24 hours. Check the <a href='/admin/email-logs/skipped' target='_blank'>skipped email logs</a> for SMTP error details.",
          ),
        )
      end
    end

    context "when email retry jobs are failing" do
      let(:retry_jobs) { 2 }

      fab!(:recent_failure) do
        Fabricate(
          :skipped_email_log,
          reason_type: SkippedEmailLog.reason_types[:custom],
          custom_reason: "smtp failed",
          created_at: 1.hour.ago,
        )
      end

      it { expect(check).to be_chill_about_it }
    end
  end
end
