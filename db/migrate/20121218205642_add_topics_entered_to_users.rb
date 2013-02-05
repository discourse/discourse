class AddTopicsEnteredToUsers < ActiveRecord::Migration
  def change
    add_column :users, :topics_entered, :integer, default: 0, null: false
    add_column :users, :posts_read_count, :integer, default: 0, null: false
  end
end
