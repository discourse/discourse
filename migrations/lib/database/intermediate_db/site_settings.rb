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

    # Creates a site setting record in the IntermediateDB
    #
    # @param name [String] The name of the site setting
    # @param value [String] The value of the site setting
    # @param action [Integer] The action to perform (one of SiteSettingAction values)
    def self.create(name:, value:, action:)
      ::Migrations::Database::IntermediateDB.insert(SQL, name, value, action)
    end
  end
end
