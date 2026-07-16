# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module PostLink
        SQL = <<~SQL
          INSERT INTO post_links (
            placeholder,
            post_id,
            target_post_id,
            target_topic_id,
            text,
            url
          )
          VALUES (
            ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `post_links` record in the IntermediateDB.
        #
        # @param placeholder       [String]
        # @param post_id           [Integer, String]
        # @param target_post_id    [Integer, String, nil]
        # @param target_topic_id   [Integer, String, nil]
        # @param text              [String, nil]
        # @param url               [String, nil]
        #
        # @return [void]
        def self.create(
          placeholder:,
          post_id:,
          target_post_id: nil,
          target_topic_id: nil,
          text: nil,
          url: nil
        )
          Migrations::Database::IntermediateDB.insert(
            SQL,
            placeholder,
            post_id,
            target_post_id,
            target_topic_id,
            text,
            url,
          )
        end
      end
    end
  end
end
