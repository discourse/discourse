# frozen_string_literal: true

class RemoveAiBotEnableDedicatedUxSetting < ActiveRecord::Migration[7.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'ai_bot_enable_dedicated_ux'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
