class AddAutoCloseBasedOnLastPostAndAutoCloseHoursToTopics < ActiveRecord::Migration
  def change
    add_column :topics, :auto_close_based_on_last_post, :boolean, default: false
    add_column :topics, :auto_close_hours, :float
  end
end
