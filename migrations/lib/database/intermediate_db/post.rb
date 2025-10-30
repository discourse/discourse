# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Post
    SQL = <<~SQL
      INSERT INTO posts (
        original_id,
        action_code,
        created_at,
        deleted_at,
        deleted_by_id,
        hidden,
        hidden_at,
        hidden_reason_id,
        image_upload_id,
        last_editor_id,
        like_count,
        locked_by_id,
        original_raw,
        post_number,
        post_type,
        raw,
        reply_to_post_number,
        reply_to_user_id,
        sort_order,
        topic_id,
        user_deleted,
        user_id,
        wiki
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `posts` record in the IntermediateDB.
    #
    # @param original_id            [Integer, String]
    # @param action_code            [String, nil]
    # @param created_at             [Time, nil]
    # @param deleted_at             [Time, nil]
    # @param deleted_by_id          [Integer, String, nil]
    # @param hidden                 [Boolean, nil]
    # @param hidden_at              [Time, nil]
    # @param hidden_reason_id       [Integer, String, nil]
    # @param image_upload_id        [String, nil]
    # @param last_editor_id         [Integer, String, nil]
    # @param like_count             [Integer, nil]
    # @param locked_by_id           [Integer, String, nil]
    # @param original_raw           [String, nil]
    # @param post_number            [Integer]
    # @param post_type              [Integer, nil]
    # @param raw                    [String]
    # @param reply_to_post_number   [Integer, nil]
    # @param reply_to_user_id       [Integer, String, nil]
    # @param sort_order             [Integer, nil]
    # @param topic_id               [Integer, String]
    # @param user_deleted           [Boolean, nil]
    # @param user_id                [Integer, String, nil]
    # @param wiki                   [Boolean, nil]
    #
    # @return [void]
    def self.create(
      original_id:,
      action_code: nil,
      created_at: nil,
      deleted_at: nil,
      deleted_by_id: nil,
      hidden: nil,
      hidden_at: nil,
      hidden_reason_id: nil,
      image_upload_id: nil,
      last_editor_id: nil,
      like_count: nil,
      locked_by_id: nil,
      original_raw: nil,
      post_number:,
      post_type: nil,
      raw:,
      reply_to_post_number: nil,
      reply_to_user_id: nil,
      sort_order: nil,
      topic_id:,
      user_deleted: nil,
      user_id: nil,
      wiki: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        action_code,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_datetime(deleted_at),
        deleted_by_id,
        ::Migrations::Database.format_boolean(hidden),
        ::Migrations::Database.format_datetime(hidden_at),
        hidden_reason_id,
        image_upload_id,
        last_editor_id,
        like_count,
        locked_by_id,
        original_raw,
        post_number,
        post_type,
        raw,
        reply_to_post_number,
        reply_to_user_id,
        sort_order,
        topic_id,
        ::Migrations::Database.format_boolean(user_deleted),
        user_id,
        ::Migrations::Database.format_boolean(wiki),
      )
    end
  end
end
