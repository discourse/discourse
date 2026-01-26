# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module PermalinkNormalization
    SQL = <<~SQL
      INSERT INTO permalink_normalizations (normalization)
      VALUES (?)
    SQL
    private_constant :SQL

    def self.create(normalization:)
      ::Migrations::Database::IntermediateDB.insert(SQL, normalization)
    end
  end
end
