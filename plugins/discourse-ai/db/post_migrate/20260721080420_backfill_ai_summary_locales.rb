# frozen_string_literal: true

class BackfillAiSummaryLocales < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    loop do
      updated_rows = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
          WITH rows AS (
            SELECT ai_summaries.id,
                   COALESCE(
                     NULLIF(topics.locale, ''),
                     (SELECT NULLIF(value, '') FROM site_settings WHERE name = 'default_locale' LIMIT 1),
                     'en'
                   ) AS locale
            FROM ai_summaries
            INNER JOIN topics
                    ON topics.id = ai_summaries.target_id
                   AND ai_summaries.target_type = 'Topic'
            WHERE ai_summaries.locale IS NULL
            LIMIT :batch_size
          )
          UPDATE ai_summaries
          SET locale = rows.locale
          FROM rows
          WHERE ai_summaries.id = rows.id
        SQL

      break if updated_rows.zero?
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
