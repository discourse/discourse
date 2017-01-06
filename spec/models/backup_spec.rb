require 'rails_helper'
require "s3_helper"

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

  shared_context 's3 helpers' do
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:resource) { Aws::S3::Resource.new(client: client) }
    let!(:s3_bucket) { resource.bucket("s3-upload-bucket") }
    let(:s3_helper) { b1.s3 }

    before(:each) do
      SiteSetting.s3_backup_bucket = "s3-upload-bucket"
      SiteSetting.s3_access_key_id = "s3-access-key-id"
      SiteSetting.s3_secret_access_key = "s3-secret-access-key"
    end
  end

  context ".after_create_hook" do
    context "when SiteSetting is true" do
      include_context "s3 helpers"

      before do
        SiteSetting.enable_s3_backups = true
      end

      it "should upload the backup to S3 with the right paths" do
        b1.path = 'some/path/backup.gz'
        File.expects(:open).with(b1.path).yields(stub)

        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        s3_object = stub

        s3_bucket.expects(:object).with(b1.filename).returns(s3_object)
        s3_object.expects(:upload_file)

        b1.after_create_hook
      end

      context "when s3_backup_bucket includes folders path" do
        before do
          SiteSetting.s3_backup_bucket = "s3-upload-bucket/discourse-backups"
        end

        it "should upload the backup to S3 with the right paths" do
          b1.path = 'some/path/backup.gz'
          File.expects(:open).with(b1.path).yields(stub)

          s3_helper.expects(:s3_bucket).returns(s3_bucket)
          s3_object = stub

          s3_bucket.expects(:object).with("discourse-backups/#{b1.filename}").returns(s3_object)
          s3_object.expects(:upload_file)

          b1.after_create_hook
        end
      end
    end

    it "calls upload_to_s3 if the SiteSetting is false" do
      SiteSetting.enable_s3_backups = false
      b1.expects(:upload_to_s3).never
      b1.after_create_hook
    end
  end

  context ".after_remove_hook" do
    include_context "s3 helpers"

    context "when SiteSetting is true" do
      before do
        SiteSetting.enable_s3_backups = true
      end

      it "should upload the backup to S3 with the right paths" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        s3_object = stub

        s3_bucket.expects(:object).with(b1.filename).returns(s3_object)
        s3_object.expects(:delete)

        b1.after_remove_hook
      end

      context "when s3_backup_bucket includes folders path" do
        before do
          SiteSetting.s3_backup_bucket = "s3-upload-bucket/discourse-backups"
        end

        it "should upload the backup to S3 with the right paths" do
          s3_helper.expects(:s3_bucket).returns(s3_bucket)
          s3_object = stub

          s3_bucket.expects(:object).with("discourse-backups/#{b1.filename}").returns(s3_object)
          s3_object.expects(:delete)

          b1.after_remove_hook
        end
      end
    end

    it "calls remove_from_s3 if the SiteSetting is false" do
      SiteSetting.enable_s3_backups = false
      b1.expects(:remove_from_s3).never
      b1.after_remove_hook
    end
  end

end
