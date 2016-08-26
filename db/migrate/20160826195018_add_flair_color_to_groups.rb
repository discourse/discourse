class AddFlairColorToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :flair_color, :string
  end
end
