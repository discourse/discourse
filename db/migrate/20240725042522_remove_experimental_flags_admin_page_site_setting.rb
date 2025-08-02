# frozen_string_literal: true

class RemoveExperimentalFlagsAdminPageSiteSetting < ActiveRecord::Migration[7.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'experimental_flags_admin_page_enabled_groups'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
