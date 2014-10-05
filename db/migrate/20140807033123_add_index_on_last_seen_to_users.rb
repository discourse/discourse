class AddIndexOnLastSeenToUsers < ActiveRecord::Migration
  def change
    add_index :users, [:last_seen_at]
  end
end
