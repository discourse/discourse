# frozen_string_literal: true

class RemoveEnableCustomSidebarSectionsSetting < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_custom_sidebar_sections'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
