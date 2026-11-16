# frozen_string_literal: true

# This file is auto-generated from the FilesDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module FilesDB
      module Download
        SQL = <<~SQL
          INSERT INTO downloads (
            id,
            original_filename
          )
          VALUES (
            ?, ?
          )
        SQL
        private_constant :SQL

        # Creates a new `downloads` record in the FilesDB.
        #
        # @param id                  [String]
        # @param original_filename   [String]
        #
        # @return [void]
        def self.create(id:, original_filename:)
          Migrations::Database::FilesDB.insert(SQL, id, original_filename)
        end
      end
    end
  end
end
