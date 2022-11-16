# frozen_string_literal: true

class HideUserTips3To5ForExistingUsers < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE user_options SET seen_popups = seen_popups || '{3, 4, 5}'"
  end

  def down
    execute "UPDATE user_options SET seen_popups = array_remove(array_remove(array_remove(seen_popups, 3), 4), 5)"
  end
end
