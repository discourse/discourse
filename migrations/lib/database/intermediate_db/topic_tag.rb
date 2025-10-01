# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module TopicTag
    SQL = <<~SQL
      INSERT INTO topic_tags (
        tag_id,
        topic_id,
        created_at
      )
      VALUES (
        ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `topic_tags` record in the IntermediateDB.
    #
    # @param tag_id       [Integer, String]
    # @param topic_id     [Integer, String]
    # @param created_at   [Time, nil]
    #
    # @return [void]
    def self.create(tag_id:, topic_id:, created_at: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        tag_id,
        topic_id,
        ::Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
