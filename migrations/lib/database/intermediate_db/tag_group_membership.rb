# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module TagGroupMembership
    SQL = <<~SQL
      INSERT INTO tag_group_memberships (
        tag_group_id,
        tag_id,
        created_at
      )
      VALUES (
        ?, ?, ?
      )
    SQL
    private_constant :SQL

    def self.create(tag_group_id:, tag_id:, created_at: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        tag_group_id,
        tag_id,
        ::Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
