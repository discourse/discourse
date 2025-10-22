# frozen_string_literal: true
class BackfillPostEmbeddings < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    if table_exists?(:ai_post_embeddings)
      # Copy data from old tables to new tables in batches.

      loop do
        count = execute(<<~SQL).cmd_tuples
        INSERT INTO ai_posts_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
        SELECT source.*
        FROM (
          SELECT old_table.*
          FROM ai_post_embeddings old_table
          LEFT JOIN ai_posts_embeddings target ON (
            target.model_id = old_table.model_id AND
            target.strategy_id = old_table.strategy_id AND
            target.post_id = old_table.post_id
          )
          WHERE target.post_id IS NULL
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
