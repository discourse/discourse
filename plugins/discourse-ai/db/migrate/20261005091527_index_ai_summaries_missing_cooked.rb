# frozen_string_literal: true
class IndexAiSummariesMissingCooked < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :ai_summaries,
                 name: "index_ai_summaries_missing_cooked",
                 if_exists: true,
                 algorithm: :concurrently
    add_index :ai_summaries,
              :id,
              name: "index_ai_summaries_missing_cooked",
              where: "summarized_cooked IS NULL AND summary_type = 0 AND target_type = 'Topic'",
              algorithm: :concurrently
  end

  def down
    remove_index :ai_summaries, name: "index_ai_summaries_missing_cooked", algorithm: :concurrently
  end
end
