# frozen_string_literal: true

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore::BackupFileHandler do
  include_context "with shared backup restore context"

  it "works with current backup file format" do
    expect_decompress_and_clean_up_to_work(
      backup_filename: "backup_since_v1.6.tar.gz",
      require_metadata_file: false,
      require_uploads: true,
    )
  end

  it "works with URLs" do
    expect_decompress_and_clean_up_to_work(
      backup_filename: "backup_since_v1.6.tar.gz",
      url: "https://example.com/backups/backup_since_v1.6.tar.gz",
      require_metadata_file: false,
      require_uploads: true,
    )
  end

  it "works with SQL only backup file" do
    expect_decompress_and_clean_up_to_work(
      backup_filename: "sql_only_backup.sql.gz",
      expected_dump_filename: "sql_only_backup.sql",
      require_metadata_file: false,
      require_uploads: false,
    )
  end

  it "works with backup file which uses wrong upload path" do
    expect_decompress_and_clean_up_to_work(
      backup_filename: "backup_with_wrong_upload_path.tar.gz",
      require_metadata_file: false,
      require_uploads: true,
      expected_upload_paths: %w[
        uploads/default/original/1X/both.txt
        uploads/default/original/1X/only-uploads.txt
        uploads/default/original/1X/only-var.txt
      ],
    ) do |upload_path|
      content = File.read(upload_path).chomp

      case File.basename(upload_path)
      when "both.txt", "only-var.txt"
        expect(content).to eq("var")
      when "only-uploads.txt"
        expect(content).to eq("uploads")
      end
    end
  end

  it "allows overriding the backup store" do
    SiteSetting.s3_backup_bucket = "s3-backup-bucket"
    SiteSetting.s3_access_key_id = "s3-access-key-id"
    SiteSetting.s3_secret_access_key = "s3-secret-access-key"
    SiteSetting.backup_location = BackupLocationSiteSetting::S3

    expect_decompress_and_clean_up_to_work(
      backup_filename: "backup_since_v1.6.tar.gz",
      require_metadata_file: false,
      require_uploads: true,
      location: BackupLocationSiteSetting::LOCAL,
    )
  end
end
