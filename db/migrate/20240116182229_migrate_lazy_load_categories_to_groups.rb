# frozen_string_literal: true

class MigrateLazyLoadCategoriesToGroups < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'lazy_load_categories_groups', data_type = 20, value = '0'
      WHERE name = 'lazy_load_categories' AND value = 't'
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET name = 'lazy_load_categories_groups', data_type = 20, value = ''
      WHERE name = 'lazy_load_categories' AND value = 'f'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET name = 'lazy_load_categories', data_type = 5, value = 't'
      WHERE name = 'lazy_load_categories_groups' AND value != ''
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET name = 'lazy_load_categories', data_type = 5, value = 'f'
      WHERE name = 'lazy_load_categories_groups' AND value = ''
    SQL
  end
end
