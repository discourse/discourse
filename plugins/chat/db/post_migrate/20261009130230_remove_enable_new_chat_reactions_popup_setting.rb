# frozen_string_literal: true
class RemoveEnableNewChatReactionsPopupSetting < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL)
      DELETE FROM site_settings WHERE name = 'enable_new_chat_reactions_popup'
    SQL

    execute(<<~SQL)
      DELETE FROM site_setting_groups WHERE name = 'enable_new_chat_reactions_popup'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
