# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module ChatChannel
    SQL = <<~SQL
      INSERT INTO chat_channels (
        original_id,
        allow_channel_wide_mentions,
        auto_join_users,
        chatable_id,
        chatable_type,
        created_at,
        delete_after_seconds,
        deleted_at,
        deleted_by_id,
        description,
        featured_in_category_id,
        icon_upload_id,
        is_group,
        messages_count,
        name,
        slug,
        status,
        threading_enabled,
        type,
        user_count
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      allow_channel_wide_mentions: nil,
      auto_join_users: nil,
      chatable_id:,
      chatable_type:,
      created_at:,
      delete_after_seconds: nil,
      deleted_at: nil,
      deleted_by_id: nil,
      description: nil,
      featured_in_category_id: nil,
      icon_upload_id: nil,
      is_group: nil,
      messages_count: nil,
      name: nil,
      slug: nil,
      status: nil,
      threading_enabled: nil,
      type: nil,
      user_count: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_boolean(allow_channel_wide_mentions),
        ::Migrations::Database.format_boolean(auto_join_users),
        chatable_id,
        chatable_type,
        ::Migrations::Database.format_datetime(created_at),
        delete_after_seconds,
        ::Migrations::Database.format_datetime(deleted_at),
        deleted_by_id,
        description,
        featured_in_category_id,
        icon_upload_id,
        ::Migrations::Database.format_boolean(is_group),
        messages_count,
        name,
        slug,
        status,
        ::Migrations::Database.format_boolean(threading_enabled),
        type,
        user_count,
      )
    end
  end
end
