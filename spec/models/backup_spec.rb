require 'spec_helper'

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
      SiteSetting.stubs(:maximum_backups).returns(3)
      Backup.any_instance.expects(:remove).never
      Backup.remove_old
    end

    it "calls remove on the backups over our limit" do
      SiteSetting.stubs(:maximum_backups).returns(1)
      b1.expects(:remove).never
      b2.expects(:remove).once
      b3.expects(:remove).once
      Backup.remove_old
    end
  end
end

