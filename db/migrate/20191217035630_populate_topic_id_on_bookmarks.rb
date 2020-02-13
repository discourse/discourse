# frozen_string_literal: true

class PopulateTopicIdOnBookmarks < ActiveRecord::Migration[6.0]
  def up
    Bookmark.where(topic_id: nil).includes(:post).find_each do |bookmark|
      bookmark.update_column(:topic_id, bookmark.post.topic_id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
