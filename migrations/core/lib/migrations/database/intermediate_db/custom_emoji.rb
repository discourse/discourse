# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module CustomEmoji
        SQL = <<~SQL
          INSERT INTO custom_emojis (
            original_id,
            created_at,
            "group",
            name,
            upload_id
          )
          VALUES (
            ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `custom_emojis` record in the IntermediateDB.
        #
        # @param original_id   [Integer, String]
        # @param created_at    [Time, nil]
        # @param group         [String, nil]
        # @param name          [String]
        # @param upload_id     [String]
        #
        # @return [void]
        def self.create(original_id:, created_at: nil, group: nil, name:, upload_id:)
          Migrations::Database::IntermediateDB.insert(
            SQL,
            original_id,
            Migrations::Database.format_datetime(created_at),
            group,
            name,
            upload_id,
          )
        end
      end
    end
  end
end
