# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module TopicAllowedGroup
        SQL = <<~SQL
          INSERT INTO topic_allowed_groups (
            topic_id,
            group_id
          )
          VALUES (
            ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `topic_allowed_groups` record in the IntermediateDB.
        #
        # @param topic_id   [Integer, String]
        # @param group_id   [Integer, String]
        #
        # @return [void]
        def self.create(topic_id:, group_id:)
          IntermediateDB.insert(SQL, topic_id, group_id)
        end
      end
    end
  end
end
