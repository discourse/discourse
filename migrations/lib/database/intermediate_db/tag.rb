# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module Tag
        SQL = <<~SQL
          INSERT INTO tags (
            original_id,
            created_at,
            description,
            locale,
            name,
            slug
          )
          VALUES (
            ?, ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `tags` record in the IntermediateDB.
        #
        # @param original_id   [Integer, String]
        # @param created_at    [Time, nil]
        # @param description   [String, nil]
        # @param locale        [String, nil]
        # @param name          [String]
        # @param slug          [String]
        #
        # @return [void]
        def self.create(original_id:, created_at: nil, description: nil, locale: nil, name:, slug:)
          IntermediateDB.insert(
            SQL,
            original_id,
            Database.format_datetime(created_at),
            description,
            locale,
            name,
            slug,
          )
        end
      end
    end
  end
end
