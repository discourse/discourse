# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserField
    SQL = <<~SQL
      INSERT INTO user_fields (
        original_id,
        created_at,
        description,
        editable,
        external_name,
        external_type,
        field_type,
        field_type_enum,
        name,
        options,
        position,
        required,
        requirement,
        searchable,
        show_on_profile,
        show_on_user_card
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      created_at:,
      description:,
      editable: nil,
      external_name: nil,
      external_type: nil,
      field_type: nil,
      field_type_enum:,
      name:,
      options: nil,
      position: nil,
      required: nil,
      requirement: nil,
      searchable: nil,
      show_on_profile: nil,
      show_on_user_card: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_datetime(created_at),
        description,
        ::Migrations::Database.format_boolean(editable),
        external_name,
        external_type,
        field_type,
        field_type_enum,
        name,
        ::Migrations::Database.to_json(options),
        position,
        ::Migrations::Database.format_boolean(required),
        requirement,
        ::Migrations::Database.format_boolean(searchable),
        ::Migrations::Database.format_boolean(show_on_profile),
        ::Migrations::Database.format_boolean(show_on_user_card),
      )
    end
  end
end
