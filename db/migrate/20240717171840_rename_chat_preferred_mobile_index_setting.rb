# frozen_string_literal: true

class RenameChatPreferredMobileIndexSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'chat_preferred_index' WHERE name = 'chat_preferred_mobile_index'"
  end

  def down
    execute "UPDATE site_settings SET name = 'chat_preferred_mobile_index' WHERE name = 'chat_preferred_index'"
  end
end
