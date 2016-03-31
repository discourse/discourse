class MigrateUncategorizedDescriptionSetting < ActiveRecord::Migration
  def change
    execute "INSERT INTO translation_overrides (locale, translation_key, value, created_at, updated_at)
             SELECT '#{I18n.locale}', 'category.uncategorized_description', value, created_at, updated_at
             FROM site_settings
             WHERE name = 'uncategorized_description'
               AND value <> 'Topics that don''t need a category, or don''t fit into any other existing category.'"

    execute "DELETE FROM site_settings WHERE name = 'uncategorized_description'"
  end
end
