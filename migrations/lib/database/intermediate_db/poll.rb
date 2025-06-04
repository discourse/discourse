# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Poll
    SQL = <<~SQL
      INSERT INTO polls (
        original_id,
        anonymous_voters,
        chart_type,
        close_at,
        created_at,
        "groups",
        max,
        min,
        name,
        post_id,
        results,
        status,
        step,
        title,
        type,
        visibility
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      anonymous_voters: nil,
      chart_type: nil,
      close_at: nil,
      created_at:,
      groups: nil,
      max: nil,
      min: nil,
      name: nil,
      post_id: nil,
      results: nil,
      status: nil,
      step: nil,
      title: nil,
      type: nil,
      visibility: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        anonymous_voters,
        chart_type,
        ::Migrations::Database.format_datetime(close_at),
        ::Migrations::Database.format_datetime(created_at),
        groups,
        max,
        min,
        name,
        post_id,
        results,
        status,
        step,
        title,
        type,
        visibility,
      )
    end
  end
end
