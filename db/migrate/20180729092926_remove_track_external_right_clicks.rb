# frozen_string_literal: true

class RemoveTrackExternalRightClicks < ActiveRecord::Migration[5.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'track_external_right_clicks'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
