# frozen_string_literal: true

class RemoveDefaultSidebarListDestinationSetting < ActiveRecord::Migration[7.0]
  def up
    execute("DELETE FROM site_settings WHERE name = 'default_sidebar_list_destination'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
