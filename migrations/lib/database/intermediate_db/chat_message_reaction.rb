# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module ChatMessageReaction
    SQL = <<~SQL
      INSERT INTO chat_message_reactions (
        chat_message_id,
        emoji,
        user_id,
        created_at
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL

    def self.create(chat_message_id:, emoji:, user_id:, created_at:)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        chat_message_id,
        emoji,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
