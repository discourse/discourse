# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_context_for_backup_restore'

describe BackupRestore::BackupFileHandler do
  include_context "shared stuff"

  def expect_decompress_and_clean_up_to_work(backup_filename:, expected_dump_filename: "dump.sql",
                                             require_metadata_file:, require_uploads:)

    freeze_time(DateTime.parse('2019-12-24 14:31:48'))

    source_file = File.join(Rails.root, "spec/fixtures/backups", backup_filename)
    target_directory = BackupRestore::LocalBackupStore.base_directory
    target_file = File.join(target_directory, backup_filename)
    FileUtils.copy_file(source_file, target_file)

    Dir.mktmpdir do |root_directory|
      current_db = RailsMultisite::ConnectionManagement.current_db
      file_handler = BackupRestore::BackupFileHandler.new(logger, backup_filename, current_db, root_directory)
      tmp_directory, db_dump_path = file_handler.decompress

      expected_tmp_path = File.join(root_directory, "tmp/restores", current_db, "2019-12-24-143148")
      expect(tmp_directory).to eq(expected_tmp_path)
      expect(db_dump_path).to eq(File.join(expected_tmp_path, expected_dump_filename))

      expect(Dir.exist?(tmp_directory)).to eq(true)
      expect(File.exist?(db_dump_path)).to eq(true)

      expect(File.exist?(File.join(tmp_directory, "meta.json"))).to eq(require_metadata_file)

      if require_uploads
        upload_filename = "uploads/default/original/3X/b/d/bd269860bb508aebcb6f08fe7289d5f117830383.png"
        expect(File.exist?(File.join(tmp_directory, upload_filename))).to eq(true)
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
end
