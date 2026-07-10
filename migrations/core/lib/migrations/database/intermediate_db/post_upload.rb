# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module PostUpload
        SQL = <<~SQL
          INSERT INTO post_uploads (
            placeholder,
            post_id,
            upload_id
          )
          VALUES (
            ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `post_uploads` record in the IntermediateDB.
        #
        # @param placeholder   [String]
        # @param post_id       [Integer, String]
        # @param upload_id     [String, nil]
        #
        # @return [void]
        def self.create(placeholder:, post_id:, upload_id: nil)
          Migrations::Database::IntermediateDB.insert(
            SQL,
            placeholder,
            post_id,
            Migrations::Database.to_blob(upload_id),
          )
        end
      end
    end
  end
end
