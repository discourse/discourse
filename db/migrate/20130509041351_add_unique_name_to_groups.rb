class AddUniqueNameToGroups < ActiveRecord::Migration[4.2]
  def change
    add_index :groups, %i[name], unique: true
  end
end
