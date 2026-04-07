# frozen_string_literal: true

class BackfillExecutionRunTimeMs < ActiveRecord::Migration[7.2]
  WAITING_NODE_TYPES = %w[action:chat_approval action:form core:wait].freeze

  def up
    # Backfill run_time_ms from execution_data for completed executions
    DB
      .query(
        "SELECT e.id, ed.data FROM discourse_workflows_executions e
       JOIN discourse_workflows_execution_data ed ON ed.execution_id = e.id
       WHERE e.run_time_ms IS NULL AND e.status IN (2, 3)",
      )
      .each do |row|
        next if row.data.blank?

        parsed =
          begin
            JSON.parse(row.data)
          rescue StandardError
            next
          end
        run_data = parsed["run_data"]
        run_data = parsed unless run_data.is_a?(Hash)
        next unless run_data.is_a?(Hash)

        steps = run_data.values.flatten
        timed =
          steps.select do |s|
            s["started_at"] && s["finished_at"] && WAITING_NODE_TYPES.exclude?(s["node_type"])
          end
        next if timed.empty?

        total = timed.sum { |s| Time.parse(s["finished_at"]) - Time.parse(s["started_at"]) }
        ms = (total * 1000).round

        DB.exec(
          "UPDATE discourse_workflows_executions SET run_time_ms = ? WHERE id = ?",
          ms,
          row.id,
        )
      end
  end

  def down
    DB.exec("UPDATE discourse_workflows_executions SET run_time_ms = NULL")
  end
end
