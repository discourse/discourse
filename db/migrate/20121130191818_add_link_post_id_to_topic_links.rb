class AddLinkPostIdToTopicLinks < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_links, :link_post_id, :integer
  end
end
