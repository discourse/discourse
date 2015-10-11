require 'rails_helper'

require_dependency 'backup'

describe Backup do

  let(:b1) { Backup.new('backup1') }
  let(:b2) { Backup.new('backup2') }
  let(:b3) { Backup.new('backup3') }

  before do
    Backup.stubs(:all).returns([b1, b2, b3])
  end

  context '#remove_old' do
    it "does nothing if there aren't more backups than the setting" do
      SiteSetting.maximum_backups = 3
      Backup.any_instance.expects(:remove).never
      Backup.remove_old
    end

    it "calls remove on the backups over our limit" do
      SiteSetting.maximum_backups = 1
      b1.expects(:remove).never
      b2.expects(:remove).once
      b3.expects(:remove).once
      Backup.remove_old
    end
  end

  context ".after_create_hook" do
    it "calls upload_to_s3 if the SiteSetting is true" do
      SiteSetting.enable_s3_backups = true
      b1.expects(:upload_to_s3).once
      b1.after_create_hook
    end

    it "calls upload_to_s3 if the SiteSetting is false" do
      SiteSetting.enable_s3_backups = false
      b1.expects(:upload_to_s3).never
      b1.after_create_hook
    end
  end

  context ".after_remove_hook" do
    it "calls remove_from_s3 if the SiteSetting is true" do
      SiteSetting.enable_s3_backups = true
      b1.expects(:remove_from_s3).once
      b1.after_remove_hook
    end

    it "calls remove_from_s3 if the SiteSetting is false" do
      SiteSetting.enable_s3_backups = false
      b1.expects(:remove_from_s3).never
      b1.after_remove_hook
    end
  end

end
