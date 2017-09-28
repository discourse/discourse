class AddFullNameToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :full_name, :string
  end
end
