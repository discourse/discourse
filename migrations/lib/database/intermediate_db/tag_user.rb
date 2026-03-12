# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module TagUser
        SQL = <<~SQL
          INSERT INTO tag_users (
            tag_id,
            user_id,
            created_at,
            notification_level
          )
          VALUES (
            ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `tag_users` record in the IntermediateDB.
        #
        # @param tag_id               [Integer, String]
        # @param user_id              [Integer, String]
        # @param created_at           [Time, nil]
        # @param notification_level   [Integer]
        #
        # @return [void]
        def self.create(tag_id:, user_id:, created_at: nil, notification_level:)
          IntermediateDB.insert(
            SQL,
            tag_id,
            user_id,
            Database.format_datetime(created_at),
            notification_level,
          )
        end
      end
    end
  end
end
