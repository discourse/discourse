class AddAutoCloseStartedAtToTopics < ActiveRecord::Migration
  def change
    add_column :topics, :auto_close_started_at, :datetime
  end
end
