# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module Group
    SQL = <<~SQL
      INSERT INTO "groups" (
        original_id,
        allow_membership_requests,
        allow_unknown_sender_topic_replies,
        automatic_membership_email_domains,
        bio_raw,
        created_at,
        default_notification_level,
        existing_id,
        flair_bg_color,
        flair_color,
        flair_icon,
        flair_upload_id,
        full_name,
        grant_trust_level,
        members_visibility_level,
        membership_request_template,
        mentionable_level,
        messageable_level,
        name,
        primary_group,
        public_admission,
        public_exit,
        publish_read_state,
        title,
        visibility_level
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `groups` record in the IntermediateDB.
    #
    # @param original_id                          [Integer, String]
    # @param allow_membership_requests            [Boolean, nil]
    # @param allow_unknown_sender_topic_replies   [Boolean, nil]
    # @param automatic_membership_email_domains   [String, nil]
    # @param bio_raw                              [String, nil]
    # @param created_at                           [Time, nil]
    # @param default_notification_level           [Integer, nil]
    # @param existing_id                          [Integer, String, nil]
    # @param flair_bg_color                       [String, nil]
    # @param flair_color                          [String, nil]
    # @param flair_icon                           [String, nil]
    # @param flair_upload_id                      [String, nil]
    # @param full_name                            [String, nil]
    # @param grant_trust_level                    [Integer, nil]
    # @param members_visibility_level             [Integer, nil]
    # @param membership_request_template          [String, nil]
    # @param mentionable_level                    [Integer, nil]
    # @param messageable_level                    [Integer, nil]
    # @param name                                 [String]
    # @param primary_group                        [Boolean, nil]
    # @param public_admission                     [Boolean, nil]
    # @param public_exit                          [Boolean, nil]
    # @param publish_read_state                   [Boolean, nil]
    # @param title                                [String, nil]
    # @param visibility_level                     [Integer, nil]
    #
    # @return [void]
    def self.create(
      original_id:,
      allow_membership_requests: nil,
      allow_unknown_sender_topic_replies: nil,
      automatic_membership_email_domains: nil,
      bio_raw: nil,
      created_at: nil,
      default_notification_level: nil,
      existing_id: nil,
      flair_bg_color: nil,
      flair_color: nil,
      flair_icon: nil,
      flair_upload_id: nil,
      full_name: nil,
      grant_trust_level: nil,
      members_visibility_level: nil,
      membership_request_template: nil,
      mentionable_level: nil,
      messageable_level: nil,
      name:,
      primary_group: nil,
      public_admission: nil,
      public_exit: nil,
      publish_read_state: nil,
      title: nil,
      visibility_level: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        original_id,
        ::Migrations::Database.format_boolean(allow_membership_requests),
        ::Migrations::Database.format_boolean(allow_unknown_sender_topic_replies),
        automatic_membership_email_domains,
        bio_raw,
        ::Migrations::Database.format_datetime(created_at),
        default_notification_level,
        existing_id,
        flair_bg_color,
        flair_color,
        flair_icon,
        flair_upload_id,
        full_name,
        grant_trust_level,
        members_visibility_level,
        membership_request_template,
        mentionable_level,
        messageable_level,
        name,
        ::Migrations::Database.format_boolean(primary_group),
        ::Migrations::Database.format_boolean(public_admission),
        ::Migrations::Database.format_boolean(public_exit),
        ::Migrations::Database.format_boolean(publish_read_state),
        title,
        visibility_level,
      )
    end
  end
end
