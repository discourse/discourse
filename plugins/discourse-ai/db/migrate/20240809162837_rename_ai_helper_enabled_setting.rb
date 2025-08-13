# frozen_string_literal: true

class RenameAiHelperEnabledSetting < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE site_settings SET name = 'ai_helper_enabled' WHERE name = 'composer_ai_helper_enabled'"
  end

  def down
    execute "UPDATE site_settings SET name = 'composer_ai_helper_enabled' WHERE name = 'ai_helper_enabled'"
  end
end
