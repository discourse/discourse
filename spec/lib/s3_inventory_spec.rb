# frozen_string_literal: true

RSpec.describe S3Inventory do
  let(:inventory) do
    S3Inventory.new(:upload, s3_inventory_bucket: "some-inventory-bucket/inventoried-bucket/prefix")
  end

  let(:csv_filename) { "#{Rails.root}/spec/fixtures/csv/s3_inventory.csv" }

  let(:system_themes_screenshots) do
    UploadReference
      .where(target_type: "ThemeField")
      .map { |screenshot| screenshot.upload.url }
      .join("\n")
  end

  before do
    inventory.s3_helper.stub_client_responses!
    inventory.stubs(:cleanup!)
  end

  it "should raise error if an inventory file is not found" do
    inventory.s3_client.stub_responses(:list_objects, contents: [])
    output = capture_stdout { inventory.backfill_etags_and_list_missing }
    expect(output).to eq("Failed to list inventory from S3\n")
  end

  it "should forward custom s3 options to the S3Helper when initializing" do
    inventory =
      S3Inventory.new(
        :upload,
        s3_inventory_bucket: "some-inventory-bucket",
        s3_options: {
          region: "us-west-1",
        },
      )

    inventory.s3_helper.stub_client_responses!

    expect(inventory.s3_helper.s3_client.config.region).to eq("us-west-1")
  end

  describe "verifying uploads" do
    before do
      freeze_time

      CSV.foreach(csv_filename, headers: false) do |row|
        next if row[S3Inventory::CSV_KEY_INDEX].exclude?("default")

        Fabricate(
          :upload,
          etag: row[S3Inventory::CSV_ETAG_INDEX],
          url:
            File.join(
              Discourse.store.absolute_base_url,
              CGI.unescape(row[S3Inventory::CSV_KEY_INDEX]),
            ),
          updated_at: 2.days.ago,
        )
      end

      @upload_1 = Fabricate(:upload, etag: "ETag", updated_at: 1.days.ago)
      @upload_2 = Fabricate(:upload, etag: "ETag2", updated_at: Time.now)
      @no_etag = Fabricate(:upload, updated_at: 2.days.ago)

      @upload_3 =
        Fabricate(
          :upload,
          etag: "ETag3",
          updated_at: 2.days.ago,
          verification_status: Upload.verification_statuses[:s3_file_missing_confirmed],
        )

      inventory.expects(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }]).times(3)
      inventory.expects(:inventory_date).times(2).returns(Time.now)
    end

    it "should display missing uploads correctly" do
      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      expect(output).to eq(
        "#{system_themes_screenshots}\n#{@upload_1.url}\n#{@no_etag.url}\n6 of 10 uploads are missing\n",
      )
      expect(Discourse.stats.get("missing_s3_uploads")).to eq(6)
    end

    it "should detect when a url match exists with a different etag" do
      upload_with_differing_tag_1 = Upload.find_by(etag: "defcaac0b4aca535c284e95f30d608d0")
      upload_with_differing_tag_1.update_columns(etag: "somethingelse")

      upload_with_differing_tag_2 = Upload.find_by(etag: "25c02eaceef4cb779fc17030d33f7f51")
      upload_with_differing_tag_2.update_columns(etag: "somethingelse")

      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      expect(output).to eq(<<~TEXT)
        #{system_themes_screenshots}
        #{upload_with_differing_tag_1.url} has different etag
        #{upload_with_differing_tag_2.url} has different etag
        #{@upload_1.url}
        #{@no_etag.url}
        8 of 10 uploads are missing
        2 of these are caused by differing etags
        Null the etag column and re-run for automatic backfill
      TEXT

      expect(Discourse.stats.get("missing_s3_uploads")).to eq(8)
    end

    it "marks missing uploads as not verified and found uploads as verified. uploads not checked will be verified nil" do
      expect(
        Upload.where(verification_status: Upload.verification_statuses[:unchecked]).count,
      ).to eq(17)

      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      verification_status = Upload.pluck(:verification_status)

      expect(
        Upload.where(verification_status: Upload.verification_statuses[:verified]).count,
      ).to eq(4)

      expect(Upload.with_invalid_etag_verification_status.count).to eq(6)

      expect(
        Upload.where(verification_status: Upload.verification_statuses[:unchecked]).count,
      ).to eq(7)
    end

    it "does not affect the updated_at date of uploads" do
      upload_1_updated = @upload_1.updated_at
      upload_2_updated = @upload_2.updated_at
      no_etag_updated = @no_etag.updated_at

      output = capture_stdout { inventory.backfill_etags_and_list_missing }

      expect(@upload_1.reload.updated_at).to eq_time(upload_1_updated)
      expect(@upload_2.reload.updated_at).to eq_time(upload_2_updated)
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
      [
        "#{Discourse.store.absolute_base_url}/uploads/default/original/1X/583bd7617044b269ae87a98684365d794e17b493.png(test",
        "25c02eaceef4cb779fc17030d33f7f51",
      ],
    ]

    files.each { |file| Fabricate(:upload, url: file[0], etag: nil) }

    inventory.expects(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }]).times(3)

    output =
      capture_stdout do
        expect { inventory.backfill_etags_and_list_missing }.to change {
          Upload.where(etag: nil).count
        }.by(-3)
      end

    expect(Upload.where.not(etag: nil).by_users.order(:url).pluck(:url, :etag)).to eq(files)
  end

  context "when site was restored from a backup" do
    before do
      freeze_time
      BackupMetadata.update_last_restore_date(Time.now)
    end

    it "should run if inventory files are at least #{described_class::WAIT_AFTER_RESTORE_DAYS.days} days older than the last restore date" do
      inventory.s3_client.stub_responses(
        :list_objects_v2,
        {
          contents: [
            {
              key: "symlink.txt",
              last_modified:
                BackupMetadata.last_restore_date + described_class::WAIT_AFTER_RESTORE_DAYS.days,
              size: 1,
            },
          ],
        },
      )

      inventory.s3_client.expects(:get_object).once

      capture_stdout { inventory.backfill_etags_and_list_missing }
    end

    it "should not run if inventory files are not at least #{described_class::WAIT_AFTER_RESTORE_DAYS.days} days older than the last restore date and reset stats count" do
      Discourse.stats.set("missing_s3_uploads", 2)

      inventory.s3_client.stub_responses(
        :list_objects_v2,
        {
          contents: [
            {
              key: "symlink.txt",
              last_modified: BackupMetadata.last_restore_date + 1.day,
              size: 1,
            },
          ],
        },
      )

      inventory.s3_client.expects(:get_object).never

      capture_stdout { inventory.backfill_etags_and_list_missing }

      expect(Discourse.stats.get("missing_s3_uploads")).to eq(0)
    end
  end

  it "should work when passed preloaded data" do
    freeze_time

    CSV.foreach(csv_filename, headers: false) do |row|
      next if row[S3Inventory::CSV_KEY_INDEX].exclude?("default")
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
              :upload,
              s3_inventory_bucket: "some-inventory-bucket",
              preloaded_inventory_file: f,
              preloaded_inventory_date: Time.now,
            )

          preloaded_inventory.backfill_etags_and_list_missing
        end
      end

    expect(output).to eq(
      "#{system_themes_screenshots}\n#{upload.url}\n#{no_etag.url}\n6 of 10 uploads are missing\n",
    )
    expect(Discourse.stats.get("missing_s3_uploads")).to eq(6)
  end
end
