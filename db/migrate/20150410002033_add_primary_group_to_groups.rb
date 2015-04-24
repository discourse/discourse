class AddPrimaryGroupToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :primary_group, :boolean, default: false, null: false
  end
end
