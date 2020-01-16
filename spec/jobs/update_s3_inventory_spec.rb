# frozen_string_literal: true

require 'rails_helper'
require "file_store/s3_store"

describe Jobs::UpdateS3Inventory do
  before do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.enable_s3_inventory = true

    store = FileStore::S3Store.new
    @client = Aws::S3::Client.new(stub_responses: true)
    store.s3_helper.stubs(:s3_client).returns(@client)
    Discourse.stubs(:store).returns(store)
  end

  it "updates the bucket policy and inventory configuration in S3" do
    id = "original"
    path = File.join(S3Inventory::INVENTORY_PREFIX, S3Inventory::INVENTORY_VERSION)

    @client.expects(:put_bucket_policy).with(
      bucket: "bucket",
      policy: %Q|{"Version":"2012-10-17","Statement":[{"Sid":"InventoryAndAnalyticsPolicy","Effect":"Allow","Principal":{"Service":"s3.amazonaws.com"},"Action":["s3:PutObject"],"Resource":["arn:aws:s3:::bucket/#{path}/*"],"Condition":{"ArnLike":{"aws:SourceArn":"arn:aws:s3:::bucket"},"StringEquals":{"s3:x-amz-acl":"bucket-owner-full-control"}}}]}|
    )
    @client.expects(:put_bucket_inventory_configuration)
    @client.expects(:put_bucket_inventory_configuration).with(
      bucket: "bucket",
      id: id,
      inventory_configuration: {
        destination: {
          s3_bucket_destination: {
            bucket: "arn:aws:s3:::bucket",
            prefix: path,
            format: "CSV"
          }
        },
        filter: {
          prefix: id
        },
        is_enabled: true,
        id: id,
        included_object_versions: "Current",
        optional_fields: ["ETag"],
        schedule: { frequency: "Daily" }
      },
      use_accelerate_endpoint: false
    )

    described_class.new.execute(nil)
  end

  it "doesn't update the policy with s3_configure_inventory_policy disabled" do
    SiteSetting.s3_configure_inventory_policy = false

    @client.expects(:put_bucket_policy).never
    @client.expects(:put_bucket_inventory_configuration).never

    described_class.new.execute(nil)
  end
end
