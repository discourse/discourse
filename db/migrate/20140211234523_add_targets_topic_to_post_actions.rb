class AddTargetsTopicToPostActions < ActiveRecord::Migration
  def change
    add_column :post_actions, :targets_topic, :boolean, default: false
  end
end
