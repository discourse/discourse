class AddTargetsTopicToPostActions < ActiveRecord::Migration[4.2]
  def change
    add_column :post_actions, :targets_topic, :boolean, default: false
  end
end
