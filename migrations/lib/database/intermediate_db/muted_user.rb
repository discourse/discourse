# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module MutedUser
    SQL = <<~SQL
      INSERT INTO muted_users (
        created_at,
        muted_user_id,
        user_id
      )
      VALUES (
        ?, ?, ?
      )
    SQL
    private_constant :SQL

    def self.create(created_at: nil, muted_user_id:, user_id:)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        ::Migrations::Database.format_datetime(created_at),
        muted_user_id,
        user_id,
      )
    end
  end
end
