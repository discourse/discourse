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
        cleared_pinned_at,
        first_visited_at,
        last_emailed_post_number,
        last_posted_at,
        last_read_post_number,
        last_visited_at,
        notification_level,
        notifications_changed_at,
        notifications_reason_id,
        total_msecs_viewed
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `topic_users` record in the IntermediateDB.
    #
    # @param topic_id                   [Integer, String]
    # @param user_id                    [Integer, String]
    # @param cleared_pinned_at          [Time, nil]
    # @param first_visited_at           [Time, nil]
    # @param last_emailed_post_number   [Integer, nil]
    # @param last_posted_at             [Time, nil]
    # @param last_read_post_number      [Integer, nil]
    # @param last_visited_at            [Time, nil]
    # @param notification_level         [Integer, nil]
    # @param notifications_changed_at   [Time, nil]
    # @param notifications_reason_id    [Integer, String, nil]
    # @param total_msecs_viewed         [Integer, nil]
    #
    # @return [void]
    def self.create(
      topic_id:,
      user_id:,
      cleared_pinned_at: nil,
      first_visited_at: nil,
      last_emailed_post_number: nil,
      last_posted_at: nil,
      last_read_post_number: nil,
      last_visited_at: nil,
      notification_level: nil,
      notifications_changed_at: nil,
      notifications_reason_id: nil,
      total_msecs_viewed: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        topic_id,
        user_id,
        ::Migrations::Database.format_datetime(cleared_pinned_at),
        ::Migrations::Database.format_datetime(first_visited_at),
        last_emailed_post_number,
        ::Migrations::Database.format_datetime(last_posted_at),
        last_read_post_number,
        ::Migrations::Database.format_datetime(last_visited_at),
        notification_level,
        ::Migrations::Database.format_datetime(notifications_changed_at),
        notifications_reason_id,
        total_msecs_viewed,
      )
    end
  end
end
