class AddAutoCloseStartedAtToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :auto_close_started_at, :datetime
  end
end
