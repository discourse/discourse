class AddFullNameToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :full_name, :string
  end
end
