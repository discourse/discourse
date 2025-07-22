# frozen_string_literal: true
class RenamedExperimentalAiBotSetting < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE site_settings SET name = 'ai_bot_enable_dedicated_ux' WHERE name = 'ai_enable_experimental_bot_ux'"
  end

  def down
    execute "UPDATE site_settings SET name = 'ai_enable_experimental_bot_ux' WHERE name = 'ai_bot_enable_dedicated_ux'"
  end
end
