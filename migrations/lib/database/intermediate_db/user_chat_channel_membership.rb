# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserChatChannelMembership
    SQL = <<~SQL
      INSERT INTO user_chat_channel_memberships (
        chat_channel_id,
        user_id,
        created_at,
        desktop_notification_level,
        "following",
        join_mode,
        last_read_message_id,
        last_unread_mention_when_emailed_id,
        last_viewed_at,
        mobile_notification_level,
        muted,
        notification_level
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      chat_channel_id:,
      user_id:,
      created_at:,
      desktop_notification_level: nil,
      following: nil,
      join_mode: nil,
      last_read_message_id: nil,
      last_unread_mention_when_emailed_id: nil,
      last_viewed_at:,
      mobile_notification_level: nil,
      muted: nil,
      notification_level: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        chat_channel_id,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        desktop_notification_level,
        ::Migrations::Database.format_boolean(following),
        join_mode,
        last_read_message_id,
        last_unread_mention_when_emailed_id,
        ::Migrations::Database.format_datetime(last_viewed_at),
        mobile_notification_level,
        ::Migrations::Database.format_boolean(muted),
        notification_level,
      )
    end
  end
end
