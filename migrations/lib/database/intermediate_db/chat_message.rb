# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module ChatMessage
    SQL = <<~SQL
      INSERT INTO chat_messages (
        original_id,
        blocks,
        chat_channel_id,
        created_at,
        created_by_sdk,
        deleted_at,
        deleted_by_id,
        excerpt,
        in_reply_to_id,
        last_editor_id,
        message,
        original_message,
        streaming,
        thread_id,
        user_id
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      blocks: nil,
      chat_channel_id:,
      created_at:,
      created_by_sdk: nil,
      deleted_at: nil,
      deleted_by_id: nil,
      excerpt: nil,
      in_reply_to_id: nil,
      last_editor_id:,
      message: nil,
      original_message: nil,
      streaming: nil,
      thread_id: nil,
      user_id: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.to_json(blocks),
        chat_channel_id,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_boolean(created_by_sdk),
        ::Migrations::Database.format_datetime(deleted_at),
        deleted_by_id,
        excerpt,
        in_reply_to_id,
        last_editor_id,
        message,
        original_message,
        ::Migrations::Database.format_boolean(streaming),
        thread_id,
        user_id,
      )
    end
  end
end
