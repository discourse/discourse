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
        name,
        tag_group_id,
        target_tag_id
      )
      VALUES (
        ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      created_at:,
      description: nil,
      name:,
      tag_group_id: nil,
      target_tag_id: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_datetime(created_at),
        description,
        name,
        tag_group_id,
        target_tag_id,
      )
    end
  end
end
