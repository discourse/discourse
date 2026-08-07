# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module EmbedEmoji
        SQL = <<~SQL
          INSERT INTO embed_emojis (
            name,
            owner_id,
            owner_type,
            placeholder
          )
          VALUES (
            ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `embed_emojis` record in the IntermediateDB.
        #
        # @param name          [String]
        # @param owner_id      [Integer, String]
        # @param owner_type    [Integer]
        #   Any constant from EmbedOwner (e.g. EmbedOwner::POST)
        # @param placeholder   [String]
        #
        # @return [void]
        #
        # @see Migrations::Database::IntermediateDB::Enums::EmbedOwner
        def self.create(name:, owner_id:, owner_type:, placeholder:)
          Migrations::Database::IntermediateDB.insert(SQL, name, owner_id, owner_type, placeholder)
        end
      end
    end
  end
end
