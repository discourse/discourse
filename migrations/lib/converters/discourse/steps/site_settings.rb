# frozen_string_literal: true

module Migrations::Converters::Discourse
  class SiteSettings < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM site_settings
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT name, value, data_type, updated_at
        FROM site_settings
        ORDER BY name
      SQL
    end

    def process_item(item)
      IntermediateDB::SiteSetting.create(
        name: item[:name],
        value: item[:value],
        last_changed_at: item[:updated_at],
        import_mode: Enums::SiteSettingImportMode::AUTO,
      )
    end
  end
end
