# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserSuspension
    SQL = <<~SQL
      INSERT INTO user_suspensions (
        user_id,
        suspended_at,
        reason,
        suspended_by_id,
        suspended_till
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_suspensions` record in the IntermediateDB.
    #
    # @param user_id           [Integer, String]
    # @param suspended_at      [Time]
    # @param reason            [String, nil]
    # @param suspended_by_id   [Integer, String, nil]
    # @param suspended_till    [Time, nil]
    #
    # @return [void]
    def self.create(user_id:, suspended_at:, reason: nil, suspended_by_id: nil, suspended_till: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        ::Migrations::Database.format_datetime(suspended_at),
        reason,
        suspended_by_id,
        ::Migrations::Database.format_datetime(suspended_till),
      )
    end
  end
end
