require 'spec_helper'

require_dependency 'jobs/scheduled/create_backup'

describe Jobs::CreateBackup do
  it "does nothing when daily backups are disabled" do
    SiteSetting.stubs(:backup_daily?).returns(false)
    BackupRestore.expects(:backup!).never
    Jobs::CreateBackup.new.execute({})
  end

  it "calls `backup!` when the daily backups are enabled" do
    SiteSetting.stubs(:backup_daily?).returns(true)
    BackupRestore.expects(:backup!).with(Discourse.system_user.id, false).once
    Jobs::CreateBackup.new.execute({})
  end
end

