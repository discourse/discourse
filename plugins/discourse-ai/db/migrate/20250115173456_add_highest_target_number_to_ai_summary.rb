# frozen_string_literal: true
class AddHighestTargetNumberToAiSummary < ActiveRecord::Migration[7.2]
  def up
    add_column :ai_summaries, :highest_target_number, :integer, null: false, default: 1

    execute <<~SQL
      UPDATE ai_summaries SET highest_target_number = GREATEST(UPPER(content_range) - 1, 1)
    SQL
  end

  def down
    drop_column :ai_summaries, :highest_target_number
  end
end
