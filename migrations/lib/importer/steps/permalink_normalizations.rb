# frozen_string_literal: true

module Migrations::Importer::Steps
  class PermalinkNormalizations < ::Migrations::Importer::Step
    def execute
      super

      normalizations = SiteSetting.permalink_normalizations
      normalizations = normalizations.blank? ? [] : normalizations.split("|")

      rows = @intermediate_db.query <<~SQL
        SELECT normalization
        FROM permalink_normalizations
        ORDER BY ROWID
      SQL

      rows.each do |row|
        normalization = row[:normalization]
        normalizations << normalization if normalizations.exclude?(normalization)
      end

      SiteSetting.permalink_normalizations = normalizations.join("|")
    end
  end
end
