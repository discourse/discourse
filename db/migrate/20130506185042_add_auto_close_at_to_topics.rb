class AddAutoCloseAtToTopics < ActiveRecord::Migration
  def change
    add_column :topics, :auto_close_at,      :datetime
    add_column :topics, :auto_close_user_id, :integer
  end
end
