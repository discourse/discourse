# frozen_string_literal: true
class SetOriginForExistingAiSummaries < ActiveRecord::Migration[7.1]
  def up
    DB.exec <<~SQL
      UPDATE ai_summaries
      SET origin = CASE WHEN summary_type = 0 THEN 0 ELSE 1 END
      WHERE origin IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
