# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module CategoryCustomField
        SQL = <<~SQL
          INSERT INTO category_custom_fields (
            category_id,
            name,
            value
          )
          VALUES (
            ?, ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `category_custom_fields` record in the IntermediateDB.
        #
        # @param category_id   [Integer, String]
        # @param name          [String]
        # @param value         [String, nil]
        #
        # @return [void]
        def self.create(category_id:, name:, value: nil)
          IntermediateDB.insert(SQL, category_id, name, value)
        end
      end
    end
  end
end
