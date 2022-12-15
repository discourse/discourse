# frozen_string_literal: true

class RenameDefaultCategoriesRegularSetting < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'default_categories_normal'
      WHERE name = 'default_categories_regular'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET name = 'default_categories_regular'
      WHERE name = 'default_categories_normal'
    SQL
  end
end
