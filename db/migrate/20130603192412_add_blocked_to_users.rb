class AddBlockedToUsers < ActiveRecord::Migration
  def change
    add_column :users, :blocked, :boolean, default: false
  end
end
