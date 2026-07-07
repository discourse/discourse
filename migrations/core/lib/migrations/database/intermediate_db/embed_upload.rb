# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module EmbedUpload
        SQL = <<~SQL
          INSERT INTO embed_uploads (
            owner_id,
            owner_type,
            placeholder,
            upload_id
          )
          VALUES (
            ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `embed_uploads` record in the IntermediateDB.
        #
        # @param owner_id      [Integer, String]
        # @param owner_type    [Integer]
        #   Any constant from EmbedOwner (e.g. EmbedOwner::POST)
        # @param placeholder   [String]
        # @param upload_id     [String, nil]
        #
        # @return [void]
        #
        # @see Migrations::Database::IntermediateDB::Enums::EmbedOwner
        def self.create(owner_id:, owner_type:, placeholder:, upload_id: nil)
          Migrations::Database::IntermediateDB.insert(
            SQL,
            owner_id,
            owner_type,
            placeholder,
            upload_id,
          )
        end
      end
    end
  end
end
