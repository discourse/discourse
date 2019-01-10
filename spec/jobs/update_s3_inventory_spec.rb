require 'rails_helper'
require "file_store/s3_store"

describe Jobs::UpdateS3Inventory do
  before do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.s3_inventory_bucket = "ghi"
    SiteSetting.enable_s3_inventory = true

    store = FileStore::S3Store.new
    @client = Aws::S3::Client.new(stub_responses: true)
    store.inventory.stubs(:s3_client).returns(@client)
    Discourse.stubs(:store).returns(store)
  end

  it "picks gravatar if system avatar is picked and gravatar was just downloaded" do
    @client.expects(:put_bucket_policy).with(
      bucket: "ghi",
      policy: "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"InventoryAndAnalyticsPolicy\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"s3.amazonaws.com\"},\"Action\":[\"s3:PutObject\"],\"Resource\":[\"arn:aws:s3:::ghi/*\"],\"Condition\":{\"ArnLike\":{\"aws:SourceArn\":\"arn:aws:s3:::bucket\"},\"StringEquals\":{\"s3:x-amz-acl\":\"bucket-owner-full-control\"}}}]}"
    )
    @client.expects(:put_bucket_inventory_configuration).with(
      bucket: "bucket",
      id: "uploads",
      inventory_configuration: {
        destination: {
          s3_bucket_destination: {
            bucket: "arn:aws:s3:::ghi",
            format: "CSV"
          }
        },
        is_enabled: true,
        id: "uploads",
        included_object_versions: "Current",
        optional_fields: ["ETag"],
        schedule: { frequency: "Daily" }
      },
      use_accelerate_endpoint: false
    )
    described_class.new.execute(nil)
  end

end
