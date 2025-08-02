# frozen_string_literal: true

class DropFlashOneboxSiteSetting < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'enable_flash_video_onebox'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
