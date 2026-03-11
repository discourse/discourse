# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserFieldValue
    SQL = <<~SQL
      INSERT INTO user_field_values (
        user_id,
        field_id,
        value,
        created_at,
        is_multiselect_field
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_field_values` record in the IntermediateDB.
    #
    # @param user_id                [Integer, String]
    # @param field_id               [Integer, String]
    # @param value                  [String]
    # @param created_at             [Time, nil]
    # @param is_multiselect_field   [Boolean, nil]
    #
    # @return [void]
    def self.create(user_id:, field_id:, value:, created_at: nil, is_multiselect_field: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        field_id,
        value,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_boolean(is_multiselect_field),
      )
    end
  end
end
