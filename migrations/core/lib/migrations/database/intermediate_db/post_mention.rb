# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module PostMention
        SQL = <<~SQL
          INSERT INTO post_mentions (
            mention_type,
            name,
            placeholder,
            post_id,
            target_id
          )
          VALUES (
            ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `post_mentions` record in the IntermediateDB.
        #
        # @param mention_type   [String, nil]
        # @param name           [String, nil]
        # @param placeholder    [String]
        # @param post_id        [Integer, String]
        # @param target_id      [Integer, String, nil]
        #
        # @return [void]
        def self.create(mention_type: nil, name: nil, placeholder:, post_id:, target_id: nil)
          Migrations::Database::IntermediateDB.insert(
            SQL,
            mention_type,
            name,
            placeholder,
            post_id,
            target_id,
          )
        end
      end
    end
  end
end
