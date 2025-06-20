# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Badge
    SQL = <<~SQL
      INSERT INTO badges (
        original_id,
        allow_title,
        auto_revoke,
        badge_grouping_id,
        badge_type_id,
        created_at,
        description,
        enabled,
        existing_id,
        icon,
        image_upload_id,
        listable,
        long_description,
        multiple_grant,
        name,
        "query",
        show_in_post_header,
        show_posts,
        target_posts,
        "trigger"
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      allow_title: nil,
      auto_revoke: nil,
      badge_grouping_id: nil,
      badge_type_id:,
      created_at: nil,
      description: nil,
      enabled: nil,
      existing_id: nil,
      icon: nil,
      image_upload_id: nil,
      listable: nil,
      long_description: nil,
      multiple_grant: nil,
      name:,
      query: nil,
      show_in_post_header: nil,
      show_posts: nil,
      target_posts: nil,
      trigger: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_boolean(allow_title),
        ::Migrations::Database.format_boolean(auto_revoke),
        badge_grouping_id,
        badge_type_id,
        ::Migrations::Database.format_datetime(created_at),
        description,
        ::Migrations::Database.format_boolean(enabled),
        existing_id,
        icon,
        image_upload_id,
        ::Migrations::Database.format_boolean(listable),
        long_description,
        ::Migrations::Database.format_boolean(multiple_grant),
        name,
        query,
        ::Migrations::Database.format_boolean(show_in_post_header),
        ::Migrations::Database.format_boolean(show_posts),
        ::Migrations::Database.format_boolean(target_posts),
        trigger,
      )
    end
  end
end
