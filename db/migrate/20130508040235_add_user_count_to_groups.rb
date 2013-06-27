class AddUserCountToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :user_count, :integer, null: false, default: 0
  end
end
