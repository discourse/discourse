# frozen_string_literal: true
class DeleteAiProblemCheckTrackers < ActiveRecord::Migration[8.0]
  def up
    tracker_identifiers = %w[ai_llm_status ai_credit_soft_limit ai_credit_hard_limit]

    DB.exec(<<~SQL, tracker_identifiers: tracker_identifiers)
      DELETE FROM problem_check_trackers 
      WHERE identifier IN (:tracker_identifiers)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
