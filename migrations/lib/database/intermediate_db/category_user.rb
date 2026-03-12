# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module CategoryUser
        SQL = <<~SQL
          INSERT INTO category_users (
            category_id,
            user_id,
            last_seen_at,
            notification_level
          )
          VALUES (
            ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `category_users` record in the IntermediateDB.
        #
        # @param category_id          [Integer, String]
        # @param user_id              [Integer, String]
        # @param last_seen_at         [Time, nil]
        # @param notification_level   [Integer]
        #
        # @return [void]
        def self.create(category_id:, user_id:, last_seen_at: nil, notification_level:)
          IntermediateDB.insert(
            SQL,
            category_id,
            user_id,
            Database.format_datetime(last_seen_at),
            notification_level,
          )
        end
      end
    end
  end
end
