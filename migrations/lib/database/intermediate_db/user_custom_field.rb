# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserCustomField
    SQL = <<~SQL
      INSERT INTO user_custom_fields (
        name,
        user_id,
        value,
        created_at
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_custom_fields` record in the IntermediateDB.
    #
    # @param name         [String]
    # @param user_id      [Integer, String]
    # @param value        [String, nil]
    # @param created_at   [Time, nil]
    #
    # @return [void]
    def self.create(name:, user_id:, value:, created_at: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        name,
        user_id,
        value,
        ::Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
