# frozen_string_literal: true
class RemoveAiTranslationBackfillMaxAgeSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'ai_translation_backfill_max_age_days'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
