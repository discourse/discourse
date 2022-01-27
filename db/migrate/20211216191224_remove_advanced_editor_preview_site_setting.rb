# frozen_string_literal: true

class RemoveAdvancedEditorPreviewSiteSetting < ActiveRecord::Migration[6.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_advanced_editor_preview_sync'"
  end

  def down
    # Nothing to do
  end
end
