require 'rails_helper'

describe Jobs::CleanUpEmailLogs do

  before do
    Fabricate(:email_log, created_at: 2.years.ago, reply_key: "something")
    Fabricate(:email_log, created_at: 2.years.ago)
    Fabricate(:email_log, created_at: 2.weeks.ago)
    Fabricate(:email_log, created_at: 2.days.ago)
  end

  it "removes old email logs without a reply_key" do
    Jobs::CleanUpEmailLogs.new.execute({})
    expect(EmailLog.count).to eq(3)
  end

  it "does not remove old email logs when delete_email_logs_after_days is 0" do
    SiteSetting.delete_email_logs_after_days = 0
    Jobs::CleanUpEmailLogs.new.execute({})
    expect(EmailLog.count).to eq(4)
  end

end
