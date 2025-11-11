# frozen_string_literal: true

class CreateBgeTopicEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_topic_embeddings_4_1, id: false do |t|
      t.integer :topic_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :topic_id, unique: true
    end
  end
end
