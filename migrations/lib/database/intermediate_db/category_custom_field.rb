# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
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
      ::Migrations::Database::IntermediateDB.insert(SQL, category_id, name, value)
    end
  end
end
