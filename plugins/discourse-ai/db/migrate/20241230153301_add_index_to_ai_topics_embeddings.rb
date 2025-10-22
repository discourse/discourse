# frozen_string_literal: true

class AddIndexToAiTopicsEmbeddings < ActiveRecord::Migration[7.2]
  def up
    add_index :ai_topics_embeddings, %i[topic_id model_id], if_not_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
