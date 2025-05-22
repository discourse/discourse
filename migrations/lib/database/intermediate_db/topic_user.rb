# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module TopicUser
    SQL = <<~SQL
      INSERT INTO topic_users (
        topic_id,
        user_id,
        bookmarked,
        cleared_pinned_at,
        first_visited_at,
        last_emailed_post_number,
        last_posted_at,
        last_read_post_number,
        last_visited_at,
        liked,
        notification_level,
        notifications_changed_at,
        notifications_reason_id,
        posted,
        total_msecs_viewed
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      topic_id:,
      user_id:,
      bookmarked: nil,
      cleared_pinned_at: nil,
      first_visited_at: nil,
      last_emailed_post_number: nil,
      last_posted_at: nil,
      last_read_post_number: nil,
      last_visited_at: nil,
      liked: nil,
      notification_level: nil,
      notifications_changed_at: nil,
      notifications_reason_id: nil,
      posted: nil,
      total_msecs_viewed: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        topic_id,
        user_id,
        ::Migrations::Database.format_boolean(bookmarked),
        ::Migrations::Database.format_datetime(cleared_pinned_at),
        ::Migrations::Database.format_datetime(first_visited_at),
        last_emailed_post_number,
        ::Migrations::Database.format_datetime(last_posted_at),
        last_read_post_number,
        ::Migrations::Database.format_datetime(last_visited_at),
        ::Migrations::Database.format_boolean(liked),
        notification_level,
        ::Migrations::Database.format_datetime(notifications_changed_at),
        notifications_reason_id,
        ::Migrations::Database.format_boolean(posted),
        total_msecs_viewed,
      )
    end
  end
end
