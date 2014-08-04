class DropTopicIdFromIncomingLinks < ActiveRecord::Migration
  def change
    remove_column :incoming_links, :topic_id
  end
end
