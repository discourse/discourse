class DropTopicIdFromIncomingLinks < ActiveRecord::Migration[4.2]
  def change
    remove_column :incoming_links, :topic_id
  end
end
