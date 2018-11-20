class AddDeletedAtToTopicEmbeds < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_embeds, :deleted_at, :datetime
    add_column :topic_embeds, :deleted_by_id, :integer, null: true
  end
end
