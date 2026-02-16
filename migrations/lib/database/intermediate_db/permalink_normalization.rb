# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "config/schema/" and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module PermalinkNormalization
    SQL = <<~SQL
      INSERT INTO permalink_normalizations (
        normalization
      )
      VALUES (
        ?
      )
    SQL
    private_constant :SQL

    # Creates a new `permalink_normalizations` record in the IntermediateDB.
    #
    # @param normalization   [String]
    #
    # @return [void]
    def self.create(normalization:)
      ::Migrations::Database::IntermediateDB.insert(SQL, normalization)
    end
  end
end
