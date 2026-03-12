# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module TagGroupPermission
        SQL = <<~SQL
          INSERT INTO tag_group_permissions (
            tag_group_id,
            group_id,
            permission_type,
            created_at
          )
          VALUES (
            ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `tag_group_permissions` record in the IntermediateDB.
        #
        # @param tag_group_id      [Integer, String]
        # @param group_id          [Integer, String]
        # @param permission_type   [Integer]
        # @param created_at        [Time, nil]
        #
        # @return [void]
        def self.create(tag_group_id:, group_id:, permission_type:, created_at: nil)
          IntermediateDB.insert(
            SQL,
            tag_group_id,
            group_id,
            permission_type,
            Database.format_datetime(created_at),
          )
        end
      end
    end
  end
end
