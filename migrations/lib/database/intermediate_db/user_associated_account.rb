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
        credentials,
        extra,
        info,
        last_used,
        provider_uid
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      provider_name:,
      user_id:,
      credentials: nil,
      extra: nil,
      info: nil,
      last_used:,
      provider_uid:
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        provider_name,
        user_id,
        ::Migrations::Database.to_json(credentials),
        ::Migrations::Database.to_json(extra),
        ::Migrations::Database.to_json(info),
        ::Migrations::Database.format_datetime(last_used),
        provider_uid,
      )
    end
  end
end
