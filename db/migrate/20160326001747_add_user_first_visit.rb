class AddUserFirstVisit < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :first_seen_at, :datetime
  end
end
