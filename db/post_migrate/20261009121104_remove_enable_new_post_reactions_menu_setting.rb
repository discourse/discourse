# frozen_string_literal: true
class RemoveEnableNewPostReactionsMenuSetting < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL)
      DELETE FROM site_settings WHERE name = 'enable_new_post_reactions_menu'
    SQL

    execute(<<~SQL)
      DELETE FROM site_setting_groups WHERE name = 'enable_new_post_reactions_menu'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
