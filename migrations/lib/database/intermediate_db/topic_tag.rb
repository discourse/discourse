# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module TopicTag
    SQL = <<~SQL
      INSERT INTO topic_tags (
        topic_id,
        tag_id,
        created_at
      )
      VALUES (
        ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `topic_tags` record in the IntermediateDB.
    #
    # @param topic_id     [Integer, String]
    # @param tag_id       [Integer, String]
    # @param created_at   [Time, nil]
    #
    # @return [void]
    def self.create(topic_id:, tag_id:, created_at: nil)
      Migrations::Database::IntermediateDB.insert(
        SQL,
        topic_id,
        tag_id,
        Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
