class AddIndexOnLastSeenToUsers < ActiveRecord::Migration[4.2]
  def change
    add_index :users, [:last_seen_at]
  end
end
