# frozen_string_literal: true

class FixAiSummariesSequence < ActiveRecord::Migration[7.0]
  def up
    begin
      execute <<-SQL
        SELECT
          SETVAL (
            'ai_summaries_id_seq',
            (
              SELECT
                GREATEST (
                  (
                    SELECT
                      MAX(id)
                    FROM
                      summary_sections
                  ),
                  (
                    SELECT
                      MAX(id)
                    FROM
                      ai_summaries
                  )
                )
            ),
            true
          );
      SQL
    rescue ActiveRecord::StatementInvalid => e
      # if the summary_table does not exist, we can ignore the error
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
