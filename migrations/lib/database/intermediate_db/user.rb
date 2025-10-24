# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module User
    SQL = <<~SQL
      INSERT INTO users (
        original_id,
        active,
        admin,
        approved,
        approved_at,
        approved_by_id,
        avatar_type,
        created_at,
        date_of_birth,
        first_seen_at,
        flair_group_id,
        group_locked_trust_level,
        ip_address,
        last_seen_at,
        locale,
        manual_locked_trust_level,
        moderator,
        name,
        original_username,
        primary_group_id,
        registration_ip_address,
        silenced_till,
        staged,
        title,
        trust_level,
        uploaded_avatar_id,
        username,
        views
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `users` record in the IntermediateDB.
    #
    # @param original_id                 [Integer, String]
    # @param active                      [Boolean, nil]
    # @param admin                       [Boolean, nil]
    # @param approved                    [Boolean, nil]
    # @param approved_at                 [Time, nil]
    # @param approved_by_id              [Integer, String, nil]
    # @param avatar_type                 [Integer, nil]
    # @param created_at                  [Time]
    # @param date_of_birth               [Time, nil]
    # @param first_seen_at               [Time, nil]
    # @param flair_group_id              [Integer, String, nil]
    # @param group_locked_trust_level    [Integer, nil]
    # @param ip_address                  [IPAddr, nil]
    # @param last_seen_at                [Time, nil]
    # @param locale                      [String, nil]
    # @param manual_locked_trust_level   [Integer, nil]
    # @param moderator                   [Boolean, nil]
    # @param name                        [String, nil]
    # @param original_username           [String, nil]
    # @param primary_group_id            [Integer, String, nil]
    # @param registration_ip_address     [IPAddr, nil]
    # @param silenced_till               [Time, nil]
    # @param staged                      [Boolean, nil]
    # @param title                       [String, nil]
    # @param trust_level                 [Integer]
    # @param uploaded_avatar_id          [String, nil]
    # @param username                    [String]
    # @param views                       [Integer, nil]
    #
    # @return [void]
    def self.create(
      original_id:,
      active: nil,
      admin: nil,
      approved: nil,
      approved_at: nil,
      approved_by_id: nil,
      avatar_type: nil,
      created_at:,
      date_of_birth: nil,
      first_seen_at: nil,
      flair_group_id: nil,
      group_locked_trust_level: nil,
      ip_address: nil,
      last_seen_at: nil,
      locale: nil,
      manual_locked_trust_level: nil,
      moderator: nil,
      name: nil,
      original_username: nil,
      primary_group_id: nil,
      registration_ip_address: nil,
      silenced_till: nil,
      staged: nil,
      title: nil,
      trust_level:,
      uploaded_avatar_id: nil,
      username:,
      views: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_boolean(active),
        ::Migrations::Database.format_boolean(admin),
        ::Migrations::Database.format_boolean(approved),
        ::Migrations::Database.format_datetime(approved_at),
        approved_by_id,
        avatar_type,
        ::Migrations::Database.format_datetime(created_at),
        ::Migrations::Database.format_date(date_of_birth),
        ::Migrations::Database.format_datetime(first_seen_at),
        flair_group_id,
        group_locked_trust_level,
        ::Migrations::Database.format_ip_address(ip_address),
        ::Migrations::Database.format_datetime(last_seen_at),
        locale,
        manual_locked_trust_level,
        ::Migrations::Database.format_boolean(moderator),
        name,
        original_username,
        primary_group_id,
        ::Migrations::Database.format_ip_address(registration_ip_address),
        ::Migrations::Database.format_datetime(silenced_till),
        ::Migrations::Database.format_boolean(staged),
        title,
        trust_level,
        uploaded_avatar_id,
        username,
        views,
      )
    end
  end
end
