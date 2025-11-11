# frozen_string_literal: true

class RenameAiHelperAddAiPmToHeaderSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'ai_bot_add_to_header' WHERE name = 'ai_helper_add_ai_pm_to_header'"
  end

  def down
    execute "UPDATE site_settings SET name = 'ai_helper_add_ai_pm_to_header'  WHERE name = 'ai_bot_add_to_header'"
  end
end
