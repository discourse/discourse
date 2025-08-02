# frozen_string_literal: true

class HideAllUserTipsForExistentUsers < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE user_options SET seen_popups = '{1, 2}'"
  end

  def down
    execute "UPDATE user_options SET seen_popups = '{}'"
  end
end
