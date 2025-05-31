# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module SiteSettings
    SQL = <<~SQL
      INSERT INTO site_settings (
        name,
        value,
        action
      )
      VALUES (
        ?, ?, ?
      )
    SQL

    def self.create(name:, value:, action:)
      ::Migrations::Database::IntermediateDB.insert(SQL, name, value, action)
    end
  end
end
