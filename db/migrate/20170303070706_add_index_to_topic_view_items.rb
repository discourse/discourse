# frozen_string_literal: true

class AddIndexToTopicViewItems < ActiveRecord::Migration[4.2]
  def change
    add_index :topic_views, [:user_id, :viewed_at]
  end
end
