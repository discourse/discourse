# frozen_string_literal: true

class CleanupSelectableAvatarsData < ActiveRecord::Migration[7.0]
  def up
    # This setting is invalid (a backup from 20200810194943_change_selectable_avatars_site_setting.rb)
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'selectable_avatars_urls'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
