class AddBlockedToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :blocked, :boolean, default: false
  end
end
