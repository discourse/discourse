class AddFieldsToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :listable, :boolean, default: true
    add_column :badges, :target_posts, :boolean, default: false
    add_column :badges, :query, :text
  end
end
