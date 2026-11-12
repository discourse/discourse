# frozen_string_literal: true

class RemoveLocaleAgnosticAiSummariesIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_on_target_id_target_type_summary_type_3355609fbb"

  def up
    remove_index :ai_summaries, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
