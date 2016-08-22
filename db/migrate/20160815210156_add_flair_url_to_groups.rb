class AddFlairUrlToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :flair_url,      :string
    add_column :groups, :flair_bg_color, :string
  end
end
