# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module CategoryModerationGroup
        SQL = <<~SQL
          INSERT INTO category_moderation_groups (
            category_id,
            group_id,
            created_at
          )
          VALUES (
            ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `category_moderation_groups` record in the IntermediateDB.
        #
        # @param category_id   [Integer, String]
        # @param group_id      [Integer, String]
        # @param created_at    [Time, nil]
        #
        # @return [void]
        def self.create(category_id:, group_id:, created_at: nil)
          Migrations::Database::IntermediateDB.insert(
            SQL,
            category_id,
            group_id,
            Migrations::Database.format_datetime(created_at),
          )
        end
      end
    end
  end
end
