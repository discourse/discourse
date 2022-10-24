# frozen_string_literal: true

class MoveTlUserHistoryToPreviousAndNewValue < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL
      UPDATE user_histories
      SET previous_value = old_tl,
          new_value = new_tl,
          details = NULL
      FROM (
          SELECT id user_history_id,
                 (REGEXP_MATCHES(details, 'old trust level: (\d+)', 'i'))[1] old_tl,
                 (REGEXP_MATCHES(details, 'new trust level: (\d+)', 'i'))[1] new_tl
          FROM user_histories
          WHERE action = 2
      ) trust_levels
      WHERE user_histories.id = trust_levels.user_history_id
    SQL
  end
end
