# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserFieldValue
    SQL = <<~SQL
      INSERT INTO user_field_values (
        created_at,
        field_id,
        is_multiselect_field,
        user_id,
        value
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    def self.create(created_at: nil, field_id:, is_multiselect_field: nil, user_id:, value: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        ::Migrations::Database.format_datetime(created_at),
        field_id,
        ::Migrations::Database.format_boolean(is_multiselect_field),
        user_id,
        value,
      )
    end
  end
end
