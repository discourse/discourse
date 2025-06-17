# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Post
    SQL = <<~SQL
      INSERT INTO posts (
        original_id,
        created_at,
        deleted_at,
        deleted_by_id,
        hidden,
        hidden_at,
        hidden_reason_id,
        image_upload_id,
        last_editor_id,
        last_version_at,
        like_count,
        locale,
        locked_by_id,
        original_raw,
        post_number,
        post_type,
        quote_count,
        raw,
        reads,
        reply_count,
        reply_to_post_id,
        reply_to_user_id,
        spam_count,
        topic_id,
        user_deleted,
        user_id,
        wiki
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create(
      original_id:,
      created_at:,
      deleted_at: nil,
      deleted_by_id: nil,
      hidden: nil,
      hidden_at: nil,
      hidden_reason_id: nil,
      image_upload_id: nil,
      last_editor_id: nil,
      last_version_at:,
      like_count: nil,
      locale: nil,
      locked_by_id: nil,
      original_raw: nil,
      post_number:,
      post_type: nil,
      quote_count: nil,
      raw:,
      reads: nil,
      reply_count: nil,
      reply_to_post_id: nil,
      reply_to_user_id: nil,
      spam_count: nil,
      topic_id:,
      user_deleted: nil,
      user_id: nil,
      wiki: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_datetime(deleted_at),
        deleted_by_id,
        ::Migrations::Database.format_boolean(hidden),
        ::Migrations::Database.format_datetime(hidden_at),
        hidden_reason_id,
        image_upload_id,
        last_editor_id,
        ::Migrations::Database.format_datetime(last_version_at),
        like_count,
        locale,
        locked_by_id,
        original_raw,
        post_number,
        post_type,
        quote_count,
        raw,
        reads,
        reply_count,
        reply_to_post_id,
        reply_to_user_id,
        spam_count,
        topic_id,
        ::Migrations::Database.format_boolean(user_deleted),
        user_id,
        ::Migrations::Database.format_boolean(wiki),
      )
    end
  end
end
