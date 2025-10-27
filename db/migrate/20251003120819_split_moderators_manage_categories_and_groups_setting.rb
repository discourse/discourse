# frozen_string_literal: true

class SplitModeratorsManageCategoriesAndGroupsSetting < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      INSERT INTO site_settings
      (name, data_type, value, created_at, updated_at)
      SELECT
        'moderators_manage_categories' AS name,
        data_type,
        value,
        NOW() AS created_at,
        NOW() AS updated_at
      FROM site_settings
      WHERE name = 'moderators_manage_categories_and_groups'
      UNION ALL
      SELECT
        'moderators_manage_groups' AS name,
        data_type,
        value,
        NOW() AS created_at,
        NOW() AS updated_at
      FROM site_settings
      WHERE name = 'moderators_manage_categories_and_groups'
    SQL

    execute(<<~SQL)
      DELETE FROM site_settings
      WHERE name = 'moderators_manage_categories_and_groups'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
