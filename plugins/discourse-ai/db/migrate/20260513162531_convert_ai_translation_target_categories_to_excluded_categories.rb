# frozen_string_literal: true

class ConvertAiTranslationTargetCategoriesToExcludedCategories < ActiveRecord::Migration[8.0]
  OLD_SETTING = "ai_translation_target_categories"
  NEW_SETTING = "ai_translation_excluded_categories"
  CATEGORY_LIST_DATA_TYPE = 20

  def up
    old_value =
      DB.query_single("SELECT value FROM site_settings WHERE name = '#{OLD_SETTING}' LIMIT 1").first

    execute "DELETE FROM site_settings WHERE name = '#{NEW_SETTING}'"

    if Migration::Helpers.existing_site?
      all_category_ids = DB.query_single("SELECT id FROM categories").map(&:to_i)
      target_category_ids = old_value.to_s.split("|").map(&:to_i)
      excluded_category_ids = all_category_ids - target_category_ids

      execute <<~SQL if excluded_category_ids.present?
          INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
          VALUES ('#{NEW_SETTING}', #{CATEGORY_LIST_DATA_TYPE}, '#{excluded_category_ids.join("|")}', NOW(), NOW())
        SQL
    end

    execute "DELETE FROM site_settings WHERE name = '#{OLD_SETTING}'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
