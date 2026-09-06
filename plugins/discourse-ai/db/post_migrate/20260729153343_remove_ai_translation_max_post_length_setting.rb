# frozen_string_literal: true
class RemoveAiTranslationMaxPostLengthSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'ai_translation_max_post_length'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
