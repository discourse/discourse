# frozen_string_literal: true

class AddAvatarDominantColorToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :dominant_color, :text, null: true
  end
end
