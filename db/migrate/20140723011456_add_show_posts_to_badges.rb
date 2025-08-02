# frozen_string_literal: true

class AddShowPostsToBadges < ActiveRecord::Migration[4.2]
  def change
    # show posts to users on badge show page
    add_column :badges, :show_posts, :boolean, null: false, default: false
  end
end
