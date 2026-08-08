# frozen_string_literal: true
class RemoveRichEditorSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'rich_editor'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
