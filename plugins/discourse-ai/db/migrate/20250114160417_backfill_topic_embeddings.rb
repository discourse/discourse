# frozen_string_literal: true
class BackfillTopicEmbeddings < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    if table_exists?(:ai_topic_embeddings)
      loop do
        count = execute(<<~SQL).cmd_tuples
        INSERT INTO ai_topics_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
        SELECT source.*
        FROM (
          SELECT old_table.*
          FROM ai_topic_embeddings old_table
          LEFT JOIN ai_topics_embeddings target ON (
            target.model_id = old_table.model_id AND
            target.strategy_id = old_table.strategy_id AND
            target.topic_id = old_table.topic_id
          )
          WHERE target.topic_id IS NULL
          LIMIT 10000
        ) source
        SQL

        break if count == 0
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
