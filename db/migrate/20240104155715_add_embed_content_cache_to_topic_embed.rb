# frozen_string_literal: true

class AddEmbedContentCacheToTopicEmbed < ActiveRecord::Migration[7.0]
  def change
    add_column :topic_embeds, :embed_content_cache, :text
  end
end
