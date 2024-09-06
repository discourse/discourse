# frozen_string_literal: true

class AddDominantColorToUserAvatars < ActiveRecord::Migration[7.1]
  def change
    add_column :user_avatars, :dominant_color, :text, null: true
  end
end
