# frozen_string_literal: true

class ConvertAiTranslationExcludedCategoriesToCategoryScope < ActiveRecord::Migration[8.0]
  OLD_SETTING = "ai_translation_excluded_categories"
  ENABLED_SETTING = "ai_translation_enabled"
  SCOPE_SETTING = "ai_translation_category_scope"
  CATEGORIES_SETTING = "ai_translation_categories"
  ENUM_DATA_TYPE = 7
  CATEGORY_LIST_DATA_TYPE = 11

  def up
    excluded_category_ids =
      DB.query_single("SELECT value FROM site_settings WHERE name = '#{OLD_SETTING}' LIMIT 1").first

    if excluded_category_ids.present?
      execute <<~SQL
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('#{SCOPE_SETTING}', #{ENUM_DATA_TYPE}, 'exclude_strict', NOW(), NOW())
      SQL

      execute <<~SQL
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('#{CATEGORIES_SETTING}', #{CATEGORY_LIST_DATA_TYPE}, '#{excluded_category_ids}', NOW(), NOW())
      SQL
    elsif ai_translation_enabled?
      execute <<~SQL
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('#{SCOPE_SETTING}', #{ENUM_DATA_TYPE}, 'all', NOW(), NOW())
      SQL
    end

    execute "DELETE FROM site_settings WHERE name = '#{OLD_SETTING}'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def ai_translation_enabled?
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = '#{ENABLED_SETTING}' LIMIT 1",
    ).first == "t"
  end
end
