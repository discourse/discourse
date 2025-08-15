# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Permalink
    SQL = <<~SQL
      INSERT INTO permalinks (
        url,
        category_id,
        created_at,
        external_url,
        post_id,
        tag_id,
        topic_id,
        user_id
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      url:,
      category_id: nil,
      created_at: nil,
      external_url: nil,
      post_id: nil,
      tag_id: nil,
      topic_id: nil,
      user_id: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        url,
        category_id,
        ::Migrations::Database.format_datetime(created_at),
        external_url,
        post_id,
        tag_id,
        topic_id,
        user_id,
      )
    end
  end
end
