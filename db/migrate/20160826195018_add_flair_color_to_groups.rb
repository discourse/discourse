class AddFlairColorToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :flair_color, :string
  end
end
