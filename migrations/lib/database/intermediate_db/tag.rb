# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Tag
    SQL = <<~SQL
      INSERT INTO tags (
        original_id,
        created_at,
        description,
        name
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL

    def self.create(original_id:, created_at: nil, description: nil, name:)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_datetime(created_at),
        description,
        name,
      )
    end
  end
end
