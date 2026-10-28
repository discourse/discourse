# frozen_string_literal: true

class CreateTopicEmbedAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :topic_embed_aliases do |t|
      t.bigint :topic_embed_id, null: false
      t.text :url_key, null: false
      t.string :url_hash, limit: 64, null: false
    end

    add_index :topic_embed_aliases, :topic_embed_id
    add_index :topic_embed_aliases, :url_hash, unique: true
  end
end
