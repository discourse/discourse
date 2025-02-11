# frozen_string_literal: true

class FixIncorrectFastTypingThresholdSetting < ActiveRecord::Migration[7.2]
  def change
    execute "UPDATE site_settings SET value = 'disabled' WHERE name = 'fast_typing_threshold' AND value = 'off'"
  end
end
