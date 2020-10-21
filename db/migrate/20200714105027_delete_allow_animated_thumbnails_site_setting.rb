# frozen_string_literal: true

class DeleteAllowAnimatedThumbnailsSiteSetting < ActiveRecord::Migration[6.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'allow_animated_thumbnails'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration.new
  end
end
