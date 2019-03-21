class AddIndexOnLastSeenToUsers < ActiveRecord::Migration[4.2]
  def change
    add_index :users, %i[last_seen_at]
  end
end
