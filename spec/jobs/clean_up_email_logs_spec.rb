require 'rails_helper'

describe Jobs::CleanUpEmailLogs do

  before do
    Fabricate(:email_log, created_at: 2.years.ago)
    Fabricate(:email_log, created_at: 2.weeks.ago)
    Fabricate(:email_log, created_at: 2.days.ago)

    Fabricate(:skipped_email_log, created_at: 2.years.ago)
    Fabricate(:skipped_email_log)
  end

  it "removes old email logs" do
    Jobs::CleanUpEmailLogs.new.execute({})
    expect(EmailLog.count).to eq(2)
    expect(SkippedEmailLog.count).to eq(1)
  end

  it "does not remove old email logs when delete_email_logs_after_days is 0" do
    SiteSetting.delete_email_logs_after_days = 0
    Jobs::CleanUpEmailLogs.new.execute({})
    expect(EmailLog.count).to eq(3)
    expect(SkippedEmailLog.count).to eq(2)
  end

end
