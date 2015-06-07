class AddTitleToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :title, :string
  end
end
