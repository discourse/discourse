class AddVisitedAtToTopicUser < ActiveRecord::Migration
  def change
    add_column :topic_users, :last_visited_at, :datetime
    add_column :topic_users, :first_visited_at, :datetime
  end
end
