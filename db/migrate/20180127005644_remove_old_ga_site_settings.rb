# frozen_string_literal: true

class RemoveOldGaSiteSettings < ActiveRecord::Migration[5.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'ga_tracking_code'"
    execute "DELETE FROM site_settings WHERE name = 'ga_domain_name'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
