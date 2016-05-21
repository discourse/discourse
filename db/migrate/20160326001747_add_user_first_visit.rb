class AddUserFirstVisit < ActiveRecord::Migration
  def change
    add_column :users, :first_seen_at, :datetime
  end
end
