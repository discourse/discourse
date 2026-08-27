# frozen_string_literal: true

class AddContentTruncatedToTopicEmbeds < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_embeds, :content_truncated, :boolean
  end
end
