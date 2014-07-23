class AddShowPostsToBadges < ActiveRecord::Migration
  def change
    # show posts to users on badge show page
    add_column :badges, :show_posts, :boolean, null: false, default: false
  end
end
