# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserAssociatedAccount
    SQL = <<~SQL
      INSERT INTO user_associated_accounts (
        provider_name,
        user_id,
        created_at,
        info,
        last_used,
        provider_uid
      )
      VALUES (
        ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_associated_accounts` record in the IntermediateDB.
    #
    # @param provider_name   [String]
    # @param user_id         [Integer, String, nil]
    # @param created_at      [Time, nil]
    # @param info            [Object, nil]
    # @param last_used       [Time, nil]
    # @param provider_uid    [String]
    #
    # @return [void]
    def self.create(
      provider_name:,
      user_id:,
      created_at: nil,
      info: nil,
      last_used: nil,
      provider_uid:
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        provider_name,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.to_json(info),
        ::Migrations::Database.format_datetime(last_used),
        provider_uid,
      )
    end
  end
end
