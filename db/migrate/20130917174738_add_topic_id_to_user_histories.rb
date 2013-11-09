class AddTopicIdToUserHistories < ActiveRecord::Migration
  def change
    add_column :user_histories, :topic_id, :integer
  end
end
