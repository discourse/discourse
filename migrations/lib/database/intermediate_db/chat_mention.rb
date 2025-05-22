# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module ChatMention
    SQL = <<~SQL
      INSERT INTO chat_mentions (
        original_id,
        chat_message_id,
        created_at,
        target_id,
        type
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL

    def self.create(original_id:, chat_message_id:, created_at:, target_id: nil, type:)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        chat_message_id,
        ::Migrations::Database.format_datetime(created_at),
        target_id,
        type,
      )
    end
  end
end
