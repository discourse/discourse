# frozen_string_literal: true

require "s3_helper"
require "s3_inventory"
require "file_store/s3_store"

RSpec.describe "S3Inventory" do
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:helper) { S3Helper.new(SiteSetting.Upload.s3_upload_bucket.downcase, "", client: client) }
  let(:inventory) { S3Inventory.new(helper, :upload) }
  let(:csv_filename) { "#{Rails.root}/spec/fixtures/csv/s3_inventory.csv" }

  before do
    setup_s3
    SiteSetting.enable_s3_inventory = true

    client.stub_responses(
      :list_objects,
      ->(context) {
        expect(context.params[:prefix]).to eq(
          "#{S3Inventory::INVENTORY_PREFIX}/#{S3Inventory::INVENTORY_VERSION}/bucket/original/hive",
        )

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
              size: 713_193,
              storage_class: "STANDARD",
            },
          ],
          next_marker: "eyJNYXJrZXIiOiBudWxsLCAiYm90b190cnVuY2F0ZV9hbW91bnQiOiAyfQ==",
        }
      },
    )

    inventory.stubs(:cleanup!)
  end

  it "should raise error if an inventory file is not found" do
    client.stub_responses(:list_objects, contents: [])
    output = capture_stdout { inventory.backfill_etags_and_list_missing }
    expect(output).to eq("Failed to list inventory from S3\n")
  end

  describe "verifying uploads" do
    before do
      freeze_time

      CSV.foreach(csv_filename, headers: false) do |row|
        next unless row[S3Inventory::CSV_KEY_INDEX].include?("default")
        Fabricate(
          :upload,
          etag: row[S3Inventory::CSV_ETAG_INDEX],
          url: File.join(Discourse.store.absolute_base_url, row[S3Inventory::CSV_KEY_INDEX]),
          updated_at: 2.days.ago,
        )
      end

      @upload1 = Fabricate(:upload, etag: "ETag", updated_at: 1.days.ago)
      @upload2 = Fabricate(:upload, etag: "ETag2", updated_at: Time.now)
      @no_etag = Fabricate(:upload, updated_at: 2.days.ago)

      inventory.expects(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }]).times(3)
      inventory.expects(:inventory_date).times(2).returns(Time.now)
    end

    it "should display missing uploads correctly" do
      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      expect(output).to eq("#{@upload1.url}\n#{@no_etag.url}\n2 of 5 uploads are missing\n")
      expect(Discourse.stats.get("missing_s3_uploads")).to eq(2)
    end

    it "should detect when a url match exists with a different etag" do
      differing_etag = Upload.find_by(etag: "defcaac0b4aca535c284e95f30d608d0")
      differing_etag.update_columns(etag: "somethingelse")

      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      expect(output).to eq(<<~TEXT)
        #{differing_etag.url} has different etag
        #{@upload1.url}
        #{@no_etag.url}
        3 of 5 uploads are missing
        1 of these are caused by differing etags
        Null the etag column and re-run for automatic backfill
      TEXT
      expect(Discourse.stats.get("missing_s3_uploads")).to eq(3)
    end

    it "marks missing uploads as not verified and found uploads as verified. uploads not checked will be verified nil" do
      expect(
        Upload.where(verification_status: Upload.verification_statuses[:unchecked]).count,
      ).to eq(12)
      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      verification_status = Upload.pluck(:verification_status)
      expect(
        Upload.where(verification_status: Upload.verification_statuses[:verified]).count,
      ).to eq(3)
      expect(
        Upload.where(verification_status: Upload.verification_statuses[:invalid_etag]).count,
      ).to eq(2)
      expect(
        Upload.where(verification_status: Upload.verification_statuses[:unchecked]).count,
      ).to eq(7)
    end

    it "does not affect the updated_at date of uploads" do
      upload_1_updated = @upload1.updated_at
      upload_2_updated = @upload2.updated_at
      no_etag_updated = @no_etag.updated_at

      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      expect(@upload1.reload.updated_at).to eq_time(upload_1_updated)
      expect(@upload2.reload.updated_at).to eq_time(upload_2_updated)
      expect(@no_etag.reload.updated_at).to eq_time(no_etag_updated)
    end
  end

  it "should backfill etags to uploads table correctly" do
    files = [
      [
        "#{Discourse.store.absolute_base_url}/uploads/default/original/1X/0184537a4f419224404d013414e913a4f56018f2.jpg",
        "defcaac0b4aca535c284e95f30d608d0",
      ],
      [
        "#{Discourse.store.absolute_base_url}/uploads/default/original/1X/0789fbf5490babc68326b9cec90eeb0d6590db05.png",
        "25c02eaceef4cb779fc17030d33f7f06",
      ],
    ]
    files.each { |file| Fabricate(:upload, url: file[0]) }

    inventory.expects(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }]).times(3)

    output =
      capture_stdout do
        expect { inventory.backfill_etags_and_list_missing }.to change {
          Upload.where(etag: nil).count
        }.by(-2)
      end

    expect(Upload.by_users.order(:url).pluck(:url, :etag)).to eq(files)
  end

  it "should work when passed preloaded data" do
    freeze_time

    CSV.foreach(csv_filename, headers: false) do |row|
      next unless row[S3Inventory::CSV_KEY_INDEX].include?("default")
      Fabricate(:upload, etag: row[S3Inventory::CSV_ETAG_INDEX], updated_at: 2.days.ago)
    end

    upload = Fabricate(:upload, etag: "ETag", updated_at: 1.days.ago)
    Fabricate(:upload, etag: "ETag2", updated_at: Time.now)
    no_etag = Fabricate(:upload, updated_at: 2.days.ago)

    output =
      capture_stdout do
        File.open(csv_filename) do |f|
          preloaded_inventory =
            S3Inventory.new(
              helper,
              :upload,
              preloaded_inventory_file: f,
              preloaded_inventory_date: Time.now,
            )
          preloaded_inventory.backfill_etags_and_list_missing
        end
      end

    expect(output).to eq("#{upload.url}\n#{no_etag.url}\n2 of 5 uploads are missing\n")
    expect(Discourse.stats.get("missing_s3_uploads")).to eq(2)
  end

  describe "s3 inventory configuration" do
    let(:bucket_name) { "s3-upload-bucket" }
    let(:subfolder_path) { "subfolder" }
    before { SiteSetting.s3_upload_bucket = "#{bucket_name}/#{subfolder_path}" }

    it "is formatted correctly for subfolders" do
      s3_helper = S3Helper.new(SiteSetting.Upload.s3_upload_bucket.downcase, "", client: client)
      config = S3Inventory.new(s3_helper, :upload).send(:inventory_configuration)

      expect(config[:destination][:s3_bucket_destination][:bucket]).to eq(
        "arn:aws:s3:::#{bucket_name}",
      )
      expect(config[:destination][:s3_bucket_destination][:prefix]).to eq(
        "#{subfolder_path}/inventory/1",
      )
      expect(config[:id]).to eq("#{subfolder_path}-original")
      expect(config[:schedule][:frequency]).to eq("Daily")
      expect(config[:included_object_versions]).to eq("Current")
      expect(config[:optional_fields]).to eq(["ETag"])
      expect(config[:filter][:prefix]).to eq(subfolder_path)
    end
  end
end
