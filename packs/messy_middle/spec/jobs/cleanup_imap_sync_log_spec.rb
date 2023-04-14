# frozen_string_literal: true

RSpec.describe Jobs::CleanupImapSyncLog do
  let(:job_class) { Jobs::CleanupImapSyncLog.new }

  it "deletes logs older than RETAIN_LOGS_DAYS" do
    log1 = ImapSyncLog.log("Test log 1", :debug)
    log2 = ImapSyncLog.log("Test log 2", :debug)
    log3 = ImapSyncLog.log("Test log 3", :debug)

    log2.update(created_at: 6.days.ago)
    log3.update(created_at: 7.days.ago)

    job_class.execute({})

    expect(ImapSyncLog.count).to eq(1)
  end

  it "does not write the log to the db if specified" do
    ImapSyncLog.debug("test", Fabricate(:group), db: false)
    expect(ImapSyncLog.count).to eq(0)
  end
end
