# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserCustomField
    SQL = <<~SQL
      INSERT INTO user_custom_fields (
        field_id,
        is_multiselect_field,
        name,
        user_id,
        value
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL

    def self.create(field_id:, is_multiselect_field:, name:, user_id:, value: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        field_id,
        ::Migrations::Database.format_boolean(is_multiselect_field),
        name,
        user_id,
        value,
      )
    end
  end
end
