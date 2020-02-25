# frozen_string_literal: true

require "rails_helper"
require "s3_helper"
require "s3_inventory"
require "file_store/s3_store"

describe "S3Inventory" do
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:helper) { S3Helper.new(SiteSetting.Upload.s3_upload_bucket.downcase, "", client: client) }
  let(:inventory) { S3Inventory.new(helper, :upload) }
  let(:csv_filename) { "#{Rails.root}/spec/fixtures/csv/s3_inventory.csv" }

  before do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.enable_s3_inventory = true

    client.stub_responses(:list_objects, -> (context) {
      expect(context.params[:prefix]).to eq("#{S3Inventory::INVENTORY_PREFIX}/#{S3Inventory::INVENTORY_VERSION}/bucket/original/hive")

      {
        contents: [
          {
            etag: "\"70ee1738b6b21e2c8a43f3a5ab0eee71\"",
            key: "example1.csv.gz",
            last_modified: Time.parse("2014-11-21T19:40:05.000Z"),
            owner: {
              display_name: "myname",
              id: "12345example25102679df27bb0ae12b3f85be6f290b936c4393484be31bebcc",
            },
            size: 11,
            storage_class: "STANDARD",
          },
          {
            etag: "\"9c8af9a76df052144598c115ef33e511\"",
            key: "example2.csv.gz",
            last_modified: Time.parse("2013-11-15T01:10:49.000Z"),
            owner: {
              display_name: "myname",
              id: "12345example25102679df27bb0ae12b3f85be6f290b936c4393484be31bebcc",
            },
            size: 713193,
            storage_class: "STANDARD",
          }
        ],
        next_marker: "eyJNYXJrZXIiOiBudWxsLCAiYm90b190cnVuY2F0ZV9hbW91bnQiOiAyfQ=="
      }
    })

    inventory.stubs(:cleanup!)
  end

  it "should raise error if an inventory file is not found" do
    client.stub_responses(:list_objects, contents: [])
    output = capture_stdout { inventory.backfill_etags_and_list_missing }
    expect(output).to eq("Failed to list inventory from S3\n")
  end

  it "should display missing uploads correctly" do
    freeze_time

    CSV.foreach(csv_filename, headers: false) do |row|
      Fabricate(:upload, etag: row[S3Inventory::CSV_ETAG_INDEX], updated_at: 2.days.ago)
    end

    upload = Fabricate(:upload, etag: "ETag", updated_at: 1.days.ago)
    Fabricate(:upload, etag: "ETag2", updated_at: Time.now)
    Fabricate(:upload, updated_at: 2.days.ago)

    inventory.expects(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }]).times(3)
    inventory.expects(:inventory_date).returns(Time.now)

    output = capture_stdout do
      inventory.backfill_etags_and_list_missing
    end

    expect(output).to eq("Listing missing post uploads...\n0 post uploads are missing.\n#{upload.url}\n1 of 5 uploads are missing\n")
    expect(Discourse.stats.get("missing_s3_uploads")).to eq(1)
  end

  it "should backfill etags to uploads table correctly" do
    files = [
      ["#{Discourse.store.absolute_base_url}/original/1X/0184537a4f419224404d013414e913a4f56018f2.jpg", "defcaac0b4aca535c284e95f30d608d0"],
      ["#{Discourse.store.absolute_base_url}/original/1X/0789fbf5490babc68326b9cec90eeb0d6590db05.png", "25c02eaceef4cb779fc17030d33f7f06"]
    ]
    files.each { |file| Fabricate(:upload, url: file[0]) }

    inventory.expects(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }]).times(3)

    output = capture_stdout do
      expect { inventory.backfill_etags_and_list_missing }.to change { Upload.where(etag: nil).count }.by(-2)
    end

    expect(Upload.by_users.order(:url).pluck(:url, :etag)).to eq(files)
  end

  it "should recover missing uploads correctly" do
    freeze_time

    CSV.foreach(csv_filename, headers: false) do |row|
      Fabricate(:upload, url: File.join(Discourse.store.absolute_base_url, row[S3Inventory::CSV_KEY_INDEX]), etag: row[S3Inventory::CSV_ETAG_INDEX], updated_at: 2.days.ago)
    end

    upload = Upload.last
    etag = upload.etag
    post = Fabricate(:post, raw: "![](#{upload.url})")
    post.link_post_uploads
    upload.delete

    inventory.expects(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }]).times(3)

    output = capture_stdout do
      inventory.backfill_etags_and_list_missing
    end

    expect(output).to eq("Listing missing post uploads...\n0 post uploads are missing.\n")
    expect(post.uploads.first.etag).to eq(etag)
  end
end
