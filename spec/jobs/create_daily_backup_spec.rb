require 'spec_helper'

require_dependency 'jobs/regular/create_daily_backup'

describe Jobs::CreateDailyBackup do
  it "does nothing when daily backups are disabled" do
    SiteSetting.stubs(:backup_daily?).returns(false)
    BackupRestore.expects(:backup!).never
    Jobs::CreateDailyBackup.new.execute({})
  end

  it "calls `backup!` when the daily backups are enabled" do
    SiteSetting.stubs(:backup_daily?).returns(true)
    BackupRestore.expects(:backup!).with(Discourse.system_user.id, { publish_to_message_bus: false }).once
    Jobs::CreateDailyBackup.new.execute({})
  end
end

