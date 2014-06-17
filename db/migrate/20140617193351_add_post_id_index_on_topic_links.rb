class AddPostIdIndexOnTopicLinks < ActiveRecord::Migration
  def up
    add_index :topic_links, :post_id
  end

  def down
    remove_index :topic_links, :post_id
  end
end
