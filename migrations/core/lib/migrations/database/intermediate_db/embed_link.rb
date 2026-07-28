# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module EmbedLink
        SQL = <<~SQL
          INSERT INTO embed_links (
            owner_id,
            owner_type,
            placeholder,
            target_id,
            target_name,
            target_post_number,
            target_suffix,
            target_topic_id,
            target_type,
            text,
            url
          )
          VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `embed_links` record in the IntermediateDB.
        #
        # @param owner_id             [Integer, String]
        # @param owner_type           [Integer]
        #   Any constant from EmbedOwner (e.g. EmbedOwner::POST)
        # @param placeholder          [String]
        # @param target_id            [Integer, String, nil]
        # @param target_name          [String, nil]
        # @param target_post_number   [Integer, nil]
        # @param target_suffix        [String, nil]
        # @param target_topic_id      [Integer, String, nil]
        # @param target_type          [Integer, nil]
        #   Any constant from LinkTarget (e.g. LinkTarget::TOPIC)
        # @param text                 [String, nil]
        # @param url                  [String, nil]
        #
        # @return [void]
        #
        # @see Migrations::Database::IntermediateDB::Enums::EmbedOwner
        # @see Migrations::Database::IntermediateDB::Enums::LinkTarget
        def self.create(
          owner_id:,
          owner_type:,
          placeholder:,
          target_id: nil,
          target_name: nil,
          target_post_number: nil,
          target_suffix: nil,
          target_topic_id: nil,
          target_type: nil,
          text: nil,
          url: nil
        )
          Migrations::Database::IntermediateDB.insert(
            SQL,
            owner_id,
            owner_type,
            placeholder,
            target_id,
            target_name,
            target_post_number,
            target_suffix,
            target_topic_id,
            target_type,
            text,
            url,
          )
        end
      end
    end
  end
end
