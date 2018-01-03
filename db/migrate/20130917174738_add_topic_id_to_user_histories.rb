class AddTopicIdToUserHistories < ActiveRecord::Migration[4.2]
  def change
    add_column :user_histories, :topic_id, :integer
  end
end
