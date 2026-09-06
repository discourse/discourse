# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module EmbedHashtag
        SQL = <<~SQL
          INSERT INTO embed_hashtags (
            hashtag_type,
            name,
            owner_id,
            owner_type,
            placeholder,
            target_id
          )
          VALUES (
            ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `embed_hashtags` record in the IntermediateDB.
        #
        # @param hashtag_type   [Integer, nil]
        #   Any constant from HashtagType (e.g. HashtagType::CATEGORY)
        # @param name           [String]
        # @param owner_id       [Integer, String]
        # @param owner_type     [Integer]
        #   Any constant from EmbedOwner (e.g. EmbedOwner::POST)
        # @param placeholder    [String]
        # @param target_id      [Integer, String, nil]
        #
        # @return [void]
        #
        # @see Migrations::Database::IntermediateDB::Enums::HashtagType
        # @see Migrations::Database::IntermediateDB::Enums::EmbedOwner
        def self.create(
          hashtag_type: nil,
          name:,
          owner_id:,
          owner_type:,
          placeholder:,
          target_id: nil
        )
          Migrations::Database::IntermediateDB.insert(
            SQL,
            hashtag_type,
            name,
            owner_id,
            owner_type,
            placeholder,
            target_id,
          )
        end
      end
    end
  end
end
