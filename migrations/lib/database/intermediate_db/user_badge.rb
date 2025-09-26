# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserBadge
    SQL = <<~SQL
      INSERT INTO user_badges (
        badge_id,
        created_at,
        granted_at,
        granted_by_id,
        is_favorite,
        post_id,
        user_id
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    def self.create(
      badge_id:,
      created_at: nil,
      granted_at:,
      granted_by_id:,
      is_favorite: nil,
      post_id: nil,
      user_id:
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        badge_id,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_datetime(granted_at),
        granted_by_id,
        ::Migrations::Database.format_boolean(is_favorite),
        post_id,
        user_id,
      )
    end
  end
end
