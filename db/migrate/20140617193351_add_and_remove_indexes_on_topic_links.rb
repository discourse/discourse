class AddAndRemoveIndexesOnTopicLinks < ActiveRecord::Migration
  def up
    # Index (topic_id) is a subset of (topic_id, post_id, url)
    remove_index :topic_links, :topic_id

    add_index :topic_links, :post_id
  end

  def down
    remove_index :topic_links, :post_id
    add_index :topic_links, :topic_id
  end
end
