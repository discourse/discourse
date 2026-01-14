# frozen_string_literal: true
class UniqueAiSummaries < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      DELETE FROM ai_summaries ais1
      USING ai_summaries ais2
      WHERE ais1.id < ais2.id
        AND ais1.target_id = ais2.target_id
        AND ais1.target_type = ais2.target_type
        AND ais1.summary_type = ais2.summary_type
    SQL

    add_index :ai_summaries, %i[target_id target_type summary_type], unique: true
  end

  def down
    remove_index :ai_summaries, column: %i[target_id target_type summary_type]
  end
end
