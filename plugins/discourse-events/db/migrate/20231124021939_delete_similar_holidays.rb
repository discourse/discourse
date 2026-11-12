# frozen_string_literal: true

class DeleteSimilarHolidays < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE
        FROM calendar_events ce
      WHERE
        ce.id IN (SELECT DISTINCT(ce3.id) FROM calendar_events ce2
                  LEFT JOIN calendar_events ce3 ON ce3.user_id = ce2.user_id AND ce3.description = ce2.description
                  WHERE ce2.start_date >= (ce3.start_date - INTERVAL '1 days')
                    AND ce2.start_date <= (ce3.start_date + INTERVAL '1 days')
                    AND ce2.timezone IS NOT NULL
                    AND ce3.timezone IS NULL
                    AND ce3.id != ce2.id
                    AND ce2.post_id IS NULL
                    AND ce3.post_id IS NULL
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
