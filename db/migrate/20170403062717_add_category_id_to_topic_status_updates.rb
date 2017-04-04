class AddCategoryIdToTopicStatusUpdates < ActiveRecord::Migration
  def change
    add_column :topic_status_updates, :category_id, :integer
  end
end
