# frozen_string_literal: true

class SpecifyRateFrequencyInBackfillSetting < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE site_settings SET name = 'ai_translation_backfill_hourly_rate' WHERE name = 'ai_translation_backfill_rate'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
