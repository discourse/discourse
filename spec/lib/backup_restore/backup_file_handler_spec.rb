# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_context_for_backup_restore'

describe BackupRestore::BackupFileHandler do
  include_context "shared stuff"

  def expect_decompress_and_clean_up_to_work(backup_filename:, expected_dump_filename: "dump.sql",
                                             require_metadata_file:, require_uploads:, expected_upload_paths: nil,
                                             location: nil)

    freeze_time(DateTime.parse('2019-12-24 14:31:48'))

    source_file = File.join(Rails.root, "spec/fixtures/backups", backup_filename)
    target_directory = BackupRestore::LocalBackupStore.base_directory
    target_file = File.join(target_directory, backup_filename)
    FileUtils.copy_file(source_file, target_file)

    Dir.mktmpdir do |root_directory|
      current_db = RailsMultisite::ConnectionManagement.current_db
      file_handler = BackupRestore::BackupFileHandler.new(
        logger, backup_filename, current_db,
        root_tmp_directory: root_directory,
        location: location
      )
      tmp_directory, db_dump_path = file_handler.decompress

      expected_tmp_path = File.join(root_directory, "tmp/restores", current_db, "2019-12-24-143148")
      expect(tmp_directory).to eq(expected_tmp_path)
      expect(db_dump_path).to eq(File.join(expected_tmp_path, expected_dump_filename))

      expect(Dir.exist?(tmp_directory)).to eq(true)
      expect(File.exist?(db_dump_path)).to eq(true)

      expect(File.exist?(File.join(tmp_directory, "meta.json"))).to eq(require_metadata_file)

      if require_uploads
        expected_upload_paths ||= ["uploads/default/original/3X/b/d/bd269860bb508aebcb6f08fe7289d5f117830383.png"]

        expected_upload_paths.each do |upload_path|
          absolute_upload_path = File.join(tmp_directory, upload_path)
          expect(File.exist?(absolute_upload_path)).to eq(true), "expected file #{upload_path} does not exist"
          yield(absolute_upload_path) if block_given?
        end
      else
        expect(Dir.exist?(File.join(tmp_directory, "uploads"))).to eq(false)
      end

      file_handler.clean_up
      expect(Dir.exist?(tmp_directory)).to eq(false)
    end
  ensure
    FileUtils.rm(target_file)

    # We don't want to delete the directory unless it is empty, otherwise this could be annoying
    # when tests run for the "default" database in a development environment.
    FileUtils.rmdir(target_directory) rescue nil
  end

  it "works with old backup file format", type: :multisite do
    test_multisite_connection("second") do
      expect_decompress_and_clean_up_to_work(
        backup_filename: "backup_till_v1.5.tar.gz",
        require_metadata_file: true,
        require_uploads: true
      )
    end
  end

  it "works with current backup file format" do
    expect_decompress_and_clean_up_to_work(
      backup_filename: "backup_since_v1.6.tar.gz",
      require_metadata_file: false,
      require_uploads: true
    )
  end

  it "works with SQL only backup file" do
    expect_decompress_and_clean_up_to_work(
      backup_filename: "sql_only_backup.sql.gz",
      expected_dump_filename: "sql_only_backup.sql",
      require_metadata_file: false,
      require_uploads: false
    )
  end

  it "works with backup file which uses wrong upload path" do
    expect_decompress_and_clean_up_to_work(
      backup_filename: "backup_with_wrong_upload_path.tar.gz",
      require_metadata_file: false,
      require_uploads: true,
      expected_upload_paths: [
        "uploads/default/original/1X/both.txt",
        "uploads/default/original/1X/only-uploads.txt",
        "uploads/default/original/1X/only-var.txt"
      ]
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
      location: BackupLocationSiteSetting::LOCAL
    )
  end
end
