# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module EmbedQuote
        SQL = <<~SQL
          INSERT INTO embed_quotes (
            owner_id,
            owner_type,
            placeholder,
            quoted_name,
            quoted_post_id,
            quoted_user_id,
            quoted_username
          )
          VALUES (
            ?, ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `embed_quotes` record in the IntermediateDB.
        #
        # @param owner_id          [Integer, String]
        # @param owner_type        [Integer]
        #   Any constant from EmbedOwner (e.g. EmbedOwner::POST)
        # @param placeholder       [String]
        # @param quoted_name       [String, nil]
        # @param quoted_post_id    [Integer, String, nil]
        # @param quoted_user_id    [Integer, String, nil]
        # @param quoted_username   [String, nil]
        #
        # @return [void]
        #
        # @see Migrations::Database::IntermediateDB::Enums::EmbedOwner
        def self.create(
          owner_id:,
          owner_type:,
          placeholder:,
          quoted_name: nil,
          quoted_post_id: nil,
          quoted_user_id: nil,
          quoted_username: nil
        )
          Migrations::Database::IntermediateDB.insert(
            SQL,
            owner_id,
            owner_type,
            placeholder,
            quoted_name,
            quoted_post_id,
            quoted_user_id,
            quoted_username,
          )
        end
      end
    end
  end
end
