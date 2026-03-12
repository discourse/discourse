# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module TagGroupMembership
        SQL = <<~SQL
          INSERT INTO tag_group_memberships (
            tag_group_id,
            tag_id,
            created_at
          )
          VALUES (
            ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `tag_group_memberships` record in the IntermediateDB.
        #
        # @param tag_group_id   [Integer, String]
        # @param tag_id         [Integer, String]
        # @param created_at     [Time, nil]
        #
        # @return [void]
        def self.create(tag_group_id:, tag_id:, created_at: nil)
          IntermediateDB.insert(SQL, tag_group_id, tag_id, Database.format_datetime(created_at))
        end
      end
    end
  end
end
