# frozen_string_literal: true

class AddTopicIdIndexToUserHistories < ActiveRecord::Migration[5.2]
  def change
    add_index :user_histories, [:topic_id, :target_user_id, :action]
  end
end
