# frozen_string_literal: true

class RemoveEnableCategoryTypeSetupSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_category_type_setup'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
