# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module UserFieldValue
    SQL = <<~SQL
      INSERT INTO user_custom_fields (
        created_at,
        field_id,
        is_multiselect_field,
        name,
        user_id,
        value
      )
      VALUES (
        ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      created_at: nil,
      field_id: nil,
      is_multiselect_field: false,
      user_id:,
      value: nil
    )
      # NOTE: name is required for user_custom_fields, but these are derived from the field_id.
      #       Set placeholder name to the field_id for now
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        ::Migrations::Database.format_datetime(created_at),
        field_id,
        ::Migrations::Database.format_boolean(is_multiselect_field),
        field_id,
        user_id,
        value,
      )
    end
  end
end
