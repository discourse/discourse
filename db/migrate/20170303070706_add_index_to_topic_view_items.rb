class AddIndexToTopicViewItems < ActiveRecord::Migration
  def change
    add_index :topic_views, [:user_id, :viewed_at]
  end
end
