# frozen_string_literal: true

class ViewsToTopicViews < ActiveRecord::Migration[4.2]
  def change
    remove_column :views, :parent_type
    rename_column :views, :parent_id, :topic_id

    rename_table :views, :topic_views

    add_index :topic_views, [:topic_id]
    add_index :topic_views, [:user_id, :topic_id]
  end
end
