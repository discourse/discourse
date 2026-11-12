# frozen_string_literal: true
class AddLowerEmbedUrlIndexToTopicEmbeds < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_topic_embeds_on_lower_embed_url"

  def up
    remove_index :topic_embeds, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :topic_embeds, "lower(embed_url)", name: INDEX_NAME, algorithm: :concurrently
  end

  def down
    remove_index :topic_embeds, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
