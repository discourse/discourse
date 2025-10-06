# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Badge
    SQL = <<~SQL
      INSERT INTO badges (
        original_id,
        allow_title,
        auto_revoke,
        badge_grouping_id,
        badge_type_id,
        created_at,
        description,
        enabled,
        existing_id,
        icon,
        image_upload_id,
        listable,
        long_description,
        multiple_grant,
        name,
        "query",
        show_in_post_header,
        show_posts,
        target_posts,
        "trigger"
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `badges` record in the IntermediateDB.
    #
    # @param original_id           [Integer, String]
    # @param allow_title           [Boolean, nil]
    # @param auto_revoke           [Boolean, nil]
    # @param badge_grouping_id     [Integer, String, nil]
    # @param badge_type_id         [Integer, String]
    # @param created_at            [Time, nil]
    # @param description           [String, nil]
    # @param enabled               [Boolean, nil]
    # @param existing_id           [Integer, String, nil]
    # @param icon                  [String, nil]
    # @param image_upload_id       [String, nil]
    # @param listable              [Boolean, nil]
    # @param long_description      [String, nil]
    # @param multiple_grant        [Boolean, nil]
    # @param name                  [String]
    # @param query                 [String, nil]
    # @param show_in_post_header   [Boolean, nil]
    # @param show_posts            [Boolean, nil]
    # @param target_posts          [Boolean, nil]
    # @param trigger               [Integer, nil]
    #
    # @return [void]
    def self.create(
      original_id:,
      allow_title: nil,
      auto_revoke: nil,
      badge_grouping_id: nil,
      badge_type_id:,
      created_at: nil,
      description: nil,
      enabled: nil,
      existing_id: nil,
      icon: nil,
      image_upload_id: nil,
      listable: nil,
      long_description: nil,
      multiple_grant: nil,
      name:,
      query: nil,
      show_in_post_header: nil,
      show_posts: nil,
      target_posts: nil,
      trigger: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_boolean(allow_title),
        ::Migrations::Database.format_boolean(auto_revoke),
        badge_grouping_id,
        badge_type_id,
        ::Migrations::Database.format_datetime(created_at),
        description,
        ::Migrations::Database.format_boolean(enabled),
        existing_id,
        icon,
        image_upload_id,
        ::Migrations::Database.format_boolean(listable),
        long_description,
        ::Migrations::Database.format_boolean(multiple_grant),
        name,
        query,
        ::Migrations::Database.format_boolean(show_in_post_header),
        ::Migrations::Database.format_boolean(show_posts),
        ::Migrations::Database.format_boolean(target_posts),
        trigger,
      )
    end
  end
end
