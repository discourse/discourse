# frozen_string_literal: true

class RenameCategorySetting < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'discourse_templates_categories'
      WHERE name = 'discourse_templates_category'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
