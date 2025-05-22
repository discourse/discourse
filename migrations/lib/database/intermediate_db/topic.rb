# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Topic
    SQL = <<~SQL
      INSERT INTO topics (
        original_id,
        archetype,
        archived,
        bannered_until,
        bumped_at,
        category_id,
        closed,
        created_at,
        deleted_at,
        deleted_by_id,
        excerpt,
        featured_link,
        featured_user1_id,
        featured_user2_id,
        featured_user3_id,
        featured_user4_id,
        has_summary,
        image_upload_id,
        incoming_link_count,
        locale,
        pinned_at,
        pinned_globally,
        pinned_until,
        slug,
        subtype,
        title,
        user_id,
        views,
        visible
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      archetype: nil,
      archived: nil,
      bannered_until: nil,
      bumped_at:,
      category_id: nil,
      closed: nil,
      created_at:,
      deleted_at: nil,
      deleted_by_id: nil,
      excerpt: nil,
      featured_link: nil,
      featured_user1_id: nil,
      featured_user2_id: nil,
      featured_user3_id: nil,
      featured_user4_id: nil,
      has_summary: nil,
      image_upload_id: nil,
      incoming_link_count: nil,
      locale: nil,
      pinned_at: nil,
      pinned_globally: nil,
      pinned_until: nil,
      slug: nil,
      subtype: nil,
      title:,
      user_id: nil,
      views: nil,
      visible: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        archetype,
        ::Migrations::Database.format_boolean(archived),
        ::Migrations::Database.format_datetime(bannered_until),
        ::Migrations::Database.format_datetime(bumped_at),
        category_id,
        ::Migrations::Database.format_boolean(closed),
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_datetime(deleted_at),
        deleted_by_id,
        excerpt,
        featured_link,
        featured_user1_id,
        featured_user2_id,
        featured_user3_id,
        featured_user4_id,
        ::Migrations::Database.format_boolean(has_summary),
        image_upload_id,
        incoming_link_count,
        locale,
        ::Migrations::Database.format_datetime(pinned_at),
        ::Migrations::Database.format_boolean(pinned_globally),
        ::Migrations::Database.format_datetime(pinned_until),
        slug,
        subtype,
        title,
        user_id,
        views,
        ::Migrations::Database.format_boolean(visible),
      )
    end
  end
end
