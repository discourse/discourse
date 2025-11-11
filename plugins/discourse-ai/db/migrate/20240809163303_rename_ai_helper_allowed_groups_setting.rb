# frozen_string_literal: true

class RenameAiHelperAllowedGroupsSetting < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE site_settings SET name = 'composer_ai_helper_allowed_groups' WHERE name = 'ai_helper_allowed_groups'"
  end

  def down
    execute "UPDATE site_settings SET name = 'ai_helper_allowed_groups' WHERE name = 'composer_ai_helper_allowed_groups'"
  end
end
