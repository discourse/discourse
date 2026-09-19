# frozen_string_literal: true

class AddLocaleAwareAiSummariesIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_ai_summaries_on_target_type_and_locale"

  def up
    remove_index :ai_summaries, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :ai_summaries,
              %i[target_id target_type summary_type locale],
              unique: true,
              nulls_not_distinct: true,
              name: INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :ai_summaries, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
