# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module TagGroup
    SQL = <<~SQL
      INSERT INTO tag_groups (
        original_id,
        created_at,
        name,
        one_per_topic,
        parent_tag_id
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL

    def self.create(original_id:, created_at:, name:, one_per_topic: nil, parent_tag_id: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_datetime(created_at),
        name,
        ::Migrations::Database.format_boolean(one_per_topic),
        parent_tag_id,
      )
    end
  end
end
