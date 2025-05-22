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
        external_url,
        external_url_placeholders,
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
      external_url: nil,
      external_url_placeholders: nil,
      post_id: nil,
      tag_id: nil,
      topic_id: nil,
      user_id: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        url,
        category_id,
        external_url,
        ::Migrations::Database.to_json(external_url_placeholders),
        post_id,
        tag_id,
        topic_id,
        user_id,
      )
    end
  end
end
