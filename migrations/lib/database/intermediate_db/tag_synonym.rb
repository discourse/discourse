# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module TagSynonym
    SQL = <<~SQL
      INSERT INTO tag_synonyms (synonym_tag_id, target_tag_id)
      VALUES (?, ?)
    SQL

    def self.create(synonym_tag_id:, target_tag_id:)
      ::Migrations::Database::IntermediateDB.insert(SQL, synonym_tag_id, target_tag_id)
    end
  end
end
