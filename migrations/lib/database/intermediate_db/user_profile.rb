# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserProfile
    SQL = <<~SQL
      INSERT INTO user_profiles (
        user_id,
        bio_raw,
        card_background_upload_id,
        featured_topic_id,
        location,
        profile_background_upload_id,
        website
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    def self.create(
      user_id:,
      bio_raw: nil,
      card_background_upload_id: nil,
      featured_topic_id: nil,
      location: nil,
      profile_background_upload_id: nil,
      website: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        bio_raw,
        card_background_upload_id,
        featured_topic_id,
        location,
        profile_background_upload_id,
        website,
      )
    end
  end
end
