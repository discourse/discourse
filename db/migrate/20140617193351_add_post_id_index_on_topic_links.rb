class AddPostIdIndexOnTopicLinks < ActiveRecord::Migration[4.2]
  def up
    add_index :topic_links, :post_id
  end

  def down
    remove_index :topic_links, :post_id
  end
end
