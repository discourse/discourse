# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module EmbedMention
        SQL = <<~SQL
          INSERT INTO embed_mentions (
            mention_type,
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

        # Creates a new `embed_mentions` record in the IntermediateDB.
        #
        # @param mention_type   [String, nil]
        # @param name           [String, nil]
        # @param owner_id       [Integer, String]
        # @param owner_type     [Integer]
        #   Any constant from EmbedOwner (e.g. EmbedOwner::POST)
        # @param placeholder    [String]
        # @param target_id      [Integer, String, nil]
        #
        # @return [void]
        #
        # @see Migrations::Database::IntermediateDB::Enums::EmbedOwner
        def self.create(
          mention_type: nil,
          name: nil,
          owner_id:,
          owner_type:,
          placeholder:,
          target_id: nil
        )
          Migrations::Database::IntermediateDB.insert(
            SQL,
            mention_type,
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
