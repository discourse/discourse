# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module UserCustomField
        SQL = <<~SQL
          INSERT INTO user_custom_fields (
            user_id,
            name,
            value,
            created_at
          )
          VALUES (
            ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `user_custom_fields` record in the IntermediateDB.
        #
        # @param user_id      [Integer, String]
        # @param name         [String]
        # @param value        [String]
        # @param created_at   [Time, nil]
        #
        # @return [void]
        def self.create(user_id:, name:, value:, created_at: nil)
          Migrations::Database::IntermediateDB.insert(
            SQL,
            user_id,
            name,
            value,
            Migrations::Database.format_datetime(created_at),
          )
        end
      end
    end
  end
end
