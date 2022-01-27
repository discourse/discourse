# frozen_string_literal: true

require "rails_helper"
require_relative "shared_context_for_backup_restore"

describe BackupRestore::BackupFileHandler, type: :multisite do
  include_context "shared stuff"

  it "works with old backup file format" do
    test_multisite_connection("second") do
      expect_decompress_and_clean_up_to_work(
        backup_filename: "backup_till_v1.5.tar.gz",
        require_metadata_file: true,
        require_uploads: true
      )
    end
  end
end
