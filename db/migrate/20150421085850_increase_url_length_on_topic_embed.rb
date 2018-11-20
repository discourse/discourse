class IncreaseUrlLengthOnTopicEmbed < ActiveRecord::Migration[4.2]
  def up
    remove_index :topic_embeds, :embed_url
    change_column :topic_embeds, :embed_url, :string, limit: 1000, null: false
    add_index :topic_embeds, :embed_url, unique: true
  end

  def down
  end
end
