# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module ChatThread
    SQL = <<~SQL
      INSERT INTO chat_threads (
        channel_id,
        original_message_id,
        original_message_user_id,
        created_at,
        force,
        last_message_id,
        original_id,
        replies_count,
        status,
        title
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      channel_id:,
      original_message_id:,
      original_message_user_id:,
      created_at:,
      force: nil,
      last_message_id: nil,
      original_id:,
      replies_count: nil,
      status: nil,
      title: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        channel_id,
        original_message_id,
        original_message_user_id,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_boolean(force),
        last_message_id,
        original_id,
        replies_count,
        status,
        title,
      )
    end
  end
end
