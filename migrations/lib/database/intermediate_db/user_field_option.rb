# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserFieldOption
    SQL = <<~SQL
      INSERT INTO user_field_options (
        user_field_id,
        value,
        created_at
      )
      VALUES (
        ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_field_options` record in the IntermediateDB.
    #
    # @param user_field_id   [Integer, String]
    # @param value           [String]
    # @param created_at      [Time, nil]
    #
    # @return [void]
    def self.create(user_field_id:, value:, created_at: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        user_field_id,
        value,
        ::Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
