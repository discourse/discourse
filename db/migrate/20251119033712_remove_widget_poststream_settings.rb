# frozen_string_literal: true
class RemoveWidgetPoststreamSettings < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN  (
       'deactivate_widgets_rendering',
       'glimmer_post_stream_mode',
       'glimmer_post_stream_mode_auto_groups'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
