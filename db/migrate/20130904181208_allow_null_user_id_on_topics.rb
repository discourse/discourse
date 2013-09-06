class AllowNullUserIdOnTopics < ActiveRecord::Migration
  def up
    change_column :topics, :user_id, :integer, null: true
  end

  def down
    change_column :topics, :user_id, :integer, null: false
  end
end
