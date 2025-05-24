# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module GroupUser
    SQL = <<~SQL
      INSERT INTO group_users (
        group_id,
        user_id,
        created_at,
        first_unread_pm_at,
        notification_level,
        original_id,
        owner
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      group_id:,
      user_id:,
      created_at:,
      first_unread_pm_at:,
      notification_level: nil,
      original_id:,
      owner: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        group_id,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_datetime(first_unread_pm_at),
        notification_level,
        original_id,
        ::Migrations::Database.format_boolean(owner),
      )
    end
  end
end
