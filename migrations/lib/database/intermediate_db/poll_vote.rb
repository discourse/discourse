# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module PollVote
    SQL = <<~SQL
      INSERT INTO poll_votes (
        poll_option_id,
        user_id,
        created_at,
        poll_id,
        rank
      )
      VALUES (
        ?, ?, ?, ?, ?
      )
    SQL

    def self.create(poll_option_id:, user_id:, created_at:, poll_id: nil, rank: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        poll_option_id,
        user_id,
        ::Migrations::Database.format_datetime(created_at),
        poll_id,
        rank,
      )
    end
  end
end
