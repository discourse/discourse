# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserEmail
    SQL = <<~SQL
      INSERT INTO user_emails (
        user_id,
        email,
        created_at,
        "primary"
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_emails` record in the IntermediateDB.
    #
    # @param user_id      [Integer, String]
    # @param email        [String]
    # @param created_at   [Time, nil]
    # @param primary      [Boolean, nil]
    #
    # @return [void]
    def self.create(user_id:, email:, created_at: nil, primary: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        email,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_boolean(primary),
      )
    end
  end
end
