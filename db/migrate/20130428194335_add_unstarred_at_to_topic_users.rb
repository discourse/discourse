class AddUnstarredAtToTopicUsers < ActiveRecord::Migration
  def change
    add_column :topic_users, :unstarred_at, :datetime
  end
end
