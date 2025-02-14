# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes, update
# the "config/intermediate_db.yml" configuration file and then run `cli schema generate` to
# regenerate this file.

module Migrations::Database::IntermediateDB
  module User
    SQL = <<~SQL
      INSERT INTO users (
        id,
        active,
        admin,
        approved,
        approved_at,
        approved_by_id,
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
        previous_visit_at,
        primary_group_id,
        registration_ip_address,
        required_fields_version,
        silenced_till,
        staged,
        suspended_at,
        suspended_till,
        title,
        trust_level,
        uploaded_avatar_id,
        username,
        views
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL

    def self.create!(
      id:,
      active: nil,
      admin: nil,
      approved: nil,
      approved_at: nil,
      approved_by_id: nil,
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
      previous_visit_at: nil,
      primary_group_id: nil,
      registration_ip_address: nil,
      required_fields_version: nil,
      silenced_till: nil,
      staged: nil,
      suspended_at: nil,
      suspended_till: nil,
      title: nil,
      trust_level:,
      uploaded_avatar_id: nil,
      username:,
      views: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        id,
        ::Migrations::Database.format_boolean(active),
        ::Migrations::Database.format_boolean(admin),
        ::Migrations::Database.format_boolean(approved),
        ::Migrations::Database.format_datetime(approved_at),
        approved_by_id,
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
        ::Migrations::Database.format_datetime(previous_visit_at),
        primary_group_id,
        ::Migrations::Database.format_ip_address(registration_ip_address),
        required_fields_version,
        ::Migrations::Database.format_datetime(silenced_till),
        ::Migrations::Database.format_boolean(staged),
        ::Migrations::Database.format_datetime(suspended_at),
        ::Migrations::Database.format_datetime(suspended_till),
        title,
        trust_level,
        uploaded_avatar_id,
        username,
        views,
      )
    end
  end
end
