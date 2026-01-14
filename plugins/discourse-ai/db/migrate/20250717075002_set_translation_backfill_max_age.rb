# frozen_string_literal: true
class SetTranslationBackfillMaxAge < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET value = '20000'
      WHERE name = 'ai_translation_backfill_max_age_days'
      AND value::integer > 20000;
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET value = '0'
      WHERE name = 'ai_translation_backfill_max_age_days'
      AND value::integer < 0;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
