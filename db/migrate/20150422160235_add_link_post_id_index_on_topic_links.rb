class AddLinkPostIdIndexOnTopicLinks < ActiveRecord::Migration
  def change
    add_index :topic_links, [:link_post_id, :reflection]
  end
end
