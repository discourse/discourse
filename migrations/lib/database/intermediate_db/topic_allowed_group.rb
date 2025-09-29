# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module TopicAllowedGroup
    SQL = <<~SQL
      INSERT INTO topic_allowed_groups (
        group_id,
        topic_id
      )
      VALUES (
        ?, ?
      )
    SQL
    private_constant :SQL

    def self.create(group_id:, topic_id:)
      ::Migrations::Database::IntermediateDB.insert(SQL, group_id, topic_id)
    end
  end
end
