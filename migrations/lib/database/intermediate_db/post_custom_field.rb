# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module PostCustomField
    SQL = <<~SQL
      INSERT INTO post_custom_fields (
        name,
        post_id,
        value
      )
      VALUES (
        ?, ?, ?
      )
    SQL

    def self.create(name:, post_id:, value: nil)
      ::Migrations::Database::IntermediateDB.insert(SQL, name, post_id, value)
    end
  end
end
