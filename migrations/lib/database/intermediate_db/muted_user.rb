# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module MutedUser
    SQL = <<~SQL
      INSERT INTO muted_users (
        muted_user_id,
        user_id,
        created_at
      )
      VALUES (
        ?, ?, ?
      )
    SQL

    def self.create(muted_user_id:, user_id:, created_at:)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        muted_user_id,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
      )
    end
  end
end
