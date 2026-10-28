# frozen_string_literal: true

# The AI slow mode tool used to pass its end time where a number of hours was expected, so its "clear slow
# mode" timers were scheduled the end's epoch seconds, read as hours, after they were created (around
# 200,000 years ahead). That keeps the end recoverable; implausible ends are cleared right away instead.
class FixClearSlowModeTimersScheduledInHours < ActiveRecord::Migration[8.1]
  CLEAR_SLOW_MODE = 9

  def up
    execute <<~SQL
      UPDATE topic_timers
      SET execute_at = CASE
            WHEN recovered.ends_at BETWEEN topic_timers.created_at AND topic_timers.created_at + INTERVAL '20 years'
              THEN recovered.ends_at
            ELSE NOW()
          END,
          updated_at = NOW()
      FROM (
        SELECT id,
               TO_TIMESTAMP(EXTRACT(EPOCH FROM execute_at - created_at) / 3600) AS ends_at
        FROM topic_timers
        WHERE status_type = #{CLEAR_SLOW_MODE}
          AND deleted_at IS NULL
          AND execute_at > NOW() + INTERVAL '100 years'
      ) recovered
      WHERE topic_timers.id = recovered.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
