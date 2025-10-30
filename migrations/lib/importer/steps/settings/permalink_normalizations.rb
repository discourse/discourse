# frozen_string_literal: true

module Migrations::Importer::Steps
  class PermalinkNormalizations < ::Migrations::Importer::Step
    def execute
      super

      normalizations_changed = false
      normalizations = SiteSetting.permalink_normalizations
      normalizations = normalizations.blank? ? [] : normalizations.split("|")

      rows = @intermediate_db.query <<~SQL
        SELECT normalization
        FROM permalink_normalizations
        ORDER BY ROWID
      SQL

      rows.each do |row|
        normalization = row[:normalization]

        if normalizations.exclude?(normalization)
          normalizations << normalization
          normalizations_changed = true
        end
      end

      if normalizations_changed
        SiteSetting.set_and_log(
          :permalink_normalizations,
          normalizations.join("|"),
          Discourse.system_user,
          I18n.t("importer.site_setting_log_message"),
        )
      end
    end
  end
end
