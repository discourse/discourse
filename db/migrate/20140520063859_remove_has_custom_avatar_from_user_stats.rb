# frozen_string_literal: true

class RemoveHasCustomAvatarFromUserStats < ActiveRecord::Migration[4.2]
  def change
    remove_column :user_stats, :has_custom_avatar
  end
end
