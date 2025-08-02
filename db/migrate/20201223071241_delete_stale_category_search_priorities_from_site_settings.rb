# frozen_string_literal: true

class DeleteStaleCategorySearchPrioritiesFromSiteSettings < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
    DELETE FROM site_settings WHERE name IN ('category_search_priority_very_low_weight', 'category_search_priority_very_high_weight')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
