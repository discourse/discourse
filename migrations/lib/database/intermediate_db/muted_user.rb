# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module MutedUser
    SQL = <<~SQL
      INSERT INTO muted_users (
        user_id,
        muted_user_id,
        created_at
      )
      VALUES (
        ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `muted_users` record in the IntermediateDB.
    #
    # @param user_id         [Integer, String]
    # @param muted_user_id   [Integer, String]
    # @param created_at      [Time, nil]
    #
    # @return [void]
    def self.create(user_id:, muted_user_id:, created_at: nil)
      Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        muted_user_id,
        Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
