# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserEmail
    SQL = <<~SQL
      INSERT INTO user_emails (
        email,
        user_id,
        created_at,
        "primary"
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL

    def self.create(email:, user_id:, created_at: nil, primary: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        email,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_boolean(primary),
      )
    end
  end
end
