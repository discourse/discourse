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
        notification_level,
        owner
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    def self.create(group_id:, user_id:, created_at: nil, notification_level: nil, owner: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        group_id,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        notification_level,
        ::Migrations::Database.format_boolean(owner),
      )
    end
  end
end
