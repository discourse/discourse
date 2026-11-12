# frozen_string_literal: true
class RemoveAiProblemCheckTrackersWithoutTargets < ActiveRecord::Migration[8.0]
  def up
    tracker_identifiers = %w[ai_llm_status ai_credit_soft_limit ai_credit_hard_limit]
    no_target = "__NULL__"

    DB.exec(<<~SQL, tracker_identifiers: tracker_identifiers, no_target: no_target)
      DELETE FROM problem_check_trackers 
      WHERE identifier IN (:tracker_identifiers) AND target = :no_target 
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
