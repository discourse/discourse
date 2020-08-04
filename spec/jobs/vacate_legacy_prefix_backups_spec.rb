# frozen_string_literal: true

require "s3_helper"
require 'rails_helper'

describe Jobs::VacateLegacyPrefixBackups, type: :multisite do
  let(:bucket_name) { "backupbucket" }

  before(:all) do
    @s3_client = Aws::S3::Client.new(stub_responses: true)
    @s3_options = { client: @s3_client }
    @objects = []
    create_backups

    @s3_client.stub_responses(:list_objects_v2, -> (context) do
      { contents: objects_with_prefix(context) }
    end)
  end

  before do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.s3_backup_bucket = bucket_name
    SiteSetting.backup_location = BackupLocationSiteSetting::S3
  end

  it "copies the backups from legacy path to new path" do
    @objects.each do |object|
      legacy_key = object[:key]
      legacy_object = @s3_client.get_object(bucket: bucket_name, key: legacy_key)

      @s3_client.expects(:copy_object).with({
        copy_source: File.join(bucket_name, legacy_key),
        bucket: bucket_name,
        key: legacy_key.sub(/^backups\//, "")
      })

      @s3_client.expects(:delete_object).with(bucket: bucket_name, key: legacy_key).returns(legacy_object)
    end

    described_class.new.execute_onceoff(s3_options: @s3_options)
  end

  def objects_with_prefix(context)
    prefix = context.params[:prefix]
    @objects.select { |obj| obj[:key].start_with?(prefix) }
  end

  def create_backups
    @objects.clear

    @objects << { key: "backups/default/b.tar.gz", size: 17, last_modified: Time.parse("2018-09-13T15:10:00Z") }
    @objects << { key: "backups/default/filename.tar.gz", size: 17, last_modified: Time.parse("2019-10-18T17:20:00Z") }
  end
end
