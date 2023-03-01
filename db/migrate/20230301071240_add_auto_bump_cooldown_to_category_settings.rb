# frozen_string_literal: true

class AddAutoBumpCooldownToCategorySettings < ActiveRecord::Migration[7.0]
  def change
    add_column :category_settings, :auto_bump_cooldown, :integer, default: 1
  end
end
