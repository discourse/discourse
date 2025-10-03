# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Topic
    SQL = <<~SQL
      INSERT INTO topics (
        original_id,
        archetype,
        archived,
        bannered_until,
        category_id,
        closed,
        created_at,
        deleted_at,
        deleted_by_id,
        external_id,
        featured_link,
        pinned_at,
        pinned_globally,
        pinned_until,
        subtype,
        title,
        user_id,
        views,
        visibility_reason_id,
        visible
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `topics` record in the IntermediateDB.
    #
    # @param original_id            [Integer, String]
    # @param archetype              [String, nil]
    # @param archived               [Boolean, nil]
    # @param bannered_until         [Time, nil]
    # @param category_id            [Integer, String, nil]
    # @param closed                 [Boolean, nil]
    # @param created_at             [Time, nil]
    # @param deleted_at             [Time, nil]
    # @param deleted_by_id          [Integer, String, nil]
    # @param external_id            [Integer, String, nil]
    # @param featured_link          [String, nil]
    # @param pinned_at              [Time, nil]
    # @param pinned_globally        [Boolean, nil]
    # @param pinned_until           [Time, nil]
    # @param subtype                [String, nil]
    # @param title                  [String]
    # @param user_id                [Integer, String, nil]
    # @param views                  [Integer, nil]
    # @param visibility_reason_id   [Integer, String, nil]
    # @param visible                [Boolean, nil]
    #
    # @return [void]
    def self.create(
      original_id:,
      archetype: nil,
      archived: nil,
      bannered_until: nil,
      category_id: nil,
      closed: nil,
      created_at: nil,
      deleted_at: nil,
      deleted_by_id: nil,
      external_id: nil,
      featured_link: nil,
      pinned_at: nil,
      pinned_globally: nil,
      pinned_until: nil,
      subtype: nil,
      title:,
      user_id: nil,
      views: nil,
      visibility_reason_id: nil,
      visible: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        archetype,
        ::Migrations::Database.format_boolean(archived),
        ::Migrations::Database.format_datetime(bannered_until),
        category_id,
        ::Migrations::Database.format_boolean(closed),
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_datetime(deleted_at),
        deleted_by_id,
        external_id,
        featured_link,
        ::Migrations::Database.format_datetime(pinned_at),
        ::Migrations::Database.format_boolean(pinned_globally),
        ::Migrations::Database.format_datetime(pinned_until),
        subtype,
        title,
        user_id,
        views,
        visibility_reason_id,
        ::Migrations::Database.format_boolean(visible),
      )
    end
  end
end
