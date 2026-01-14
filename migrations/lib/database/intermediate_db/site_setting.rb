# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module SiteSetting
    SQL = <<~SQL
      INSERT INTO site_settings (
        name,
        import_mode,
        last_changed_at,
        value
      )
      VALUES (
        ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `site_settings` record in the IntermediateDB.
    #
    # @param name              [String]
    # @param import_mode       [Integer]
    #   Any constant from SiteSettingImportMode (e.g. SiteSettingImportMode::AUTO)
    # @param last_changed_at   [Time, nil]
    # @param value             [String, nil]
    #
    # @return [void]
    #
    # @see Migrations::Database::IntermediateDB::Enums::SiteSettingImportMode
    def self.create(name:, import_mode:, last_changed_at: nil, value: nil)
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        name,
        import_mode,
        ::Migrations::Database.format_datetime(last_changed_at),
        value,
      )
    end
  end
end
