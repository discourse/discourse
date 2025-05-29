# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module TagUser
    SQL = <<~SQL
      INSERT INTO tag_users (
        tag_id,
        user_id,
        created_at,
        notification_level,
        original_id
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL

    def self.create(tag_id:, user_id:, created_at:, notification_level:, original_id:)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        tag_id,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        notification_level,
        original_id,
      )
    end
  end
end
