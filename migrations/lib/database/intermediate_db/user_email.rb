# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserEmail
    SQL = <<~SQL
      INSERT INTO user_emails (
        email,
        created_at,
        "primary",
        user_id
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL

    def self.create(email:, created_at: nil, primary: nil, user_id:)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        email,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_boolean(primary),
        user_id,
      )
    end
  end
end
