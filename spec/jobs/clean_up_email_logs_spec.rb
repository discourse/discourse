require 'rails_helper'

describe Jobs::CleanUpEmailLogs do
  let!(:email_log) { Fabricate(:email_log, created_at: 2.years.ago) }
  let!(:email_log2) { Fabricate(:email_log, created_at: 2.weeks.ago) }
  let!(:email_log3) { Fabricate(:email_log, created_at: 2.days.ago) }

  let!(:skipped_email_log) do
    Fabricate(:skipped_email_log, created_at: 2.years.ago)
  end

  let!(:skipped_email_log2) { Fabricate(:skipped_email_log) }

  it "removes old email logs" do
    Jobs::CleanUpEmailLogs.new.execute({})
    expect(EmailLog.all).to contain_exactly(email_log2, email_log3)
    expect(SkippedEmailLog.all).to contain_exactly(skipped_email_log2)
  end

  it "does not remove old email logs when delete_email_logs_after_days is 0" do
    SiteSetting.delete_email_logs_after_days = 0
    Jobs::CleanUpEmailLogs.new.execute({})

    expect(EmailLog.all).to contain_exactly(email_log, email_log2, email_log3)

    expect(SkippedEmailLog.all).to contain_exactly(
      skipped_email_log,
      skipped_email_log2
    )
  end

end
