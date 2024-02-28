# frozen_string_literal: true

class RemoveEnableExperimentalAdminUiGroupsSiteSettings < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_experimental_admin_ui_groups'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
