# frozen_string_literal: true

class MigrateUncategorizedCategoryName < ActiveRecord::Migration[5.2]
  def change
    execute <<~SQL
      INSERT INTO translation_overrides (locale, translation_key, value, created_at, updated_at)
      SELECT '#{I18n.locale}', 'uncategorized_category_name', name, now(), now()
      FROM categories
      WHERE id = #{SiteSetting.uncategorized_category_id} AND LOWER(name) <> 'uncategorized';
    SQL
  end
end
