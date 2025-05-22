# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module PollOption
    SQL = <<~SQL
      INSERT INTO poll_options (
        original_id,
        anonymous_votes,
        created_at,
        poll_id
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL

    def self.create(original_id:, anonymous_votes: nil, created_at:, poll_id: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        anonymous_votes,
        ::Migrations::Database.format_datetime(created_at),
        poll_id,
      )
    end
  end
end
