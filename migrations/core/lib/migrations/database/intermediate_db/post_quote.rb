# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module PostQuote
        SQL = <<~SQL
          INSERT INTO post_quotes (
            placeholder,
            post_id,
            quoted_post_id,
            quoted_user_id,
            quoted_username
          )
          VALUES (
            ?, ?, ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `post_quotes` record in the IntermediateDB.
        #
        # @param placeholder       [String]
        # @param post_id           [Integer, String]
        # @param quoted_post_id    [Integer, String, nil]
        # @param quoted_user_id    [Integer, String, nil]
        # @param quoted_username   [String, nil]
        #
        # @return [void]
        def self.create(
          placeholder:,
          post_id:,
          quoted_post_id: nil,
          quoted_user_id: nil,
          quoted_username: nil
        )
          Migrations::Database::IntermediateDB.insert(
            SQL,
            placeholder,
            post_id,
            quoted_post_id,
            quoted_user_id,
            quoted_username,
          )
        end
      end
    end
  end
end
