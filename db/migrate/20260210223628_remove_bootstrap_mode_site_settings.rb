# frozen_string_literal: true
class RemoveBootstrapModeSiteSettings < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'bootstrap_mode_enabled'"
    execute "DELETE FROM site_settings WHERE name = 'bootstrap_mode_min_users'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
