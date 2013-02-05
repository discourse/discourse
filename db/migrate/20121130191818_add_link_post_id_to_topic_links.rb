class AddLinkPostIdToTopicLinks < ActiveRecord::Migration
  def change
    add_column :topic_links, :link_post_id, :integer
  end
end
