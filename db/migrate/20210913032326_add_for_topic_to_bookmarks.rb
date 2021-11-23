# frozen_string_literal: true

class AddForTopicToBookmarks < ActiveRecord::Migration[6.1]
  def change
    add_column :bookmarks, :for_topic, :boolean, default: false, null: false
    add_index :bookmarks, [:user_id, :post_id, :for_topic], unique: true
    if index_exists?(:bookmarks, [:user_id, :post_id])
      remove_index :bookmarks, [:user_id, :post_id]
    end
  end
end
