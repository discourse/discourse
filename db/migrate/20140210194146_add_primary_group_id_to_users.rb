class AddPrimaryGroupIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :primary_group_id, :integer, null: true
  end
end
