# frozen_string_literal: true
class RemoveEnableNewComposerActionsSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_new_composer_actions'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
