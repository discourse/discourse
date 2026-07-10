# frozen_string_literal: true

# This file is auto-generated from the FilesDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module FilesDB
      module UploadResult
        SQL = <<~SQL
          INSERT INTO upload_results (
            id,
            markdown,
            skip_details,
            skip_reason,
            status,
            upload_id
          )
          VALUES (
            ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `upload_results` record in the FilesDB.
        #
        # @param id             [String]
        # @param markdown       [String, nil]
        # @param skip_details   [String, nil]
        # @param skip_reason    [String, nil]
        #   Any constant from UploadSkipReason (e.g. UploadSkipReason::DOWNLOAD_ERROR)
        # @param status         [String]
        #   Any constant from UploadResultStatus (e.g. UploadResultStatus::ERROR)
        # @param upload_id      [Integer, nil]
        #
        # @return [void]
        #
        # @see Migrations::Database::FilesDB::Enums::UploadSkipReason
        # @see Migrations::Database::FilesDB::Enums::UploadResultStatus
        def self.create(
          id:,
          markdown: nil,
          skip_details: nil,
          skip_reason: nil,
          status:,
          upload_id: nil
        )
          Migrations::Database::FilesDB.insert(
            SQL,
            id,
            markdown,
            skip_details,
            skip_reason,
            status,
            upload_id,
          )
        end
      end
    end
  end
end
