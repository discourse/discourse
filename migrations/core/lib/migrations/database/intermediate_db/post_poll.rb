# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module PostPoll
        SQL = <<~SQL
          INSERT INTO post_polls (
            placeholder,
            poll_id,
            post_id
          )
          VALUES (
            ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `post_polls` record in the IntermediateDB.
        #
        # @param placeholder   [String]
        # @param poll_id       [Integer, String, nil]
        # @param post_id       [Integer, String]
        #
        # @return [void]
        def self.create(placeholder:, poll_id: nil, post_id:)
          Migrations::Database::IntermediateDB.insert(SQL, placeholder, poll_id, post_id)
        end
      end
    end
  end
end
