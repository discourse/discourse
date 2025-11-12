# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module CategoryModerationGroup
    SQL = <<~SQL
      INSERT INTO category_moderation_groups (
        category_id,
        group_id
      )
      VALUES (
        ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `category_moderation_groups` record in the IntermediateDB.
    #
    # @param category_id   [Integer, String, nil]
    # @param group_id      [Integer, String, nil]
    #
    # @return [void]
    def self.create(category_id:, group_id:)
      ::Migrations::Database::IntermediateDB.insert(SQL, category_id, group_id)
    end
  end
end
