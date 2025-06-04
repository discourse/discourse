# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserChatThreadMembership
    SQL = <<~SQL
      INSERT INTO user_chat_thread_memberships (
        thread_id,
        user_id,
        created_at,
        last_read_message_id,
        last_unread_message_when_emailed_id,
        notification_level,
        thread_title_prompt_seen
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      thread_id:,
      user_id:,
      created_at:,
      last_read_message_id: nil,
      last_unread_message_when_emailed_id: nil,
      notification_level: nil,
      thread_title_prompt_seen: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        thread_id,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        last_read_message_id,
        last_unread_message_when_emailed_id,
        notification_level,
        ::Migrations::Database.format_boolean(thread_title_prompt_seen),
      )
    end
  end
end
