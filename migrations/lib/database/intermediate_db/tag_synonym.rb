# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module TagSynonym
        SQL = <<~SQL
          INSERT INTO tag_synonyms (
            synonym_tag_id,
            target_tag_id
          )
          VALUES (
            ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `tag_synonyms` record in the IntermediateDB.
        #
        # @param synonym_tag_id   [Integer, String]
        # @param target_tag_id    [Integer, String]
        #
        # @return [void]
        def self.create(synonym_tag_id:, target_tag_id:)
          IntermediateDB.insert(SQL, synonym_tag_id, target_tag_id)
        end
      end
    end
  end
end
