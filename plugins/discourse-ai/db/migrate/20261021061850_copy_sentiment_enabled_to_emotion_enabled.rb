# frozen_string_literal: true

class CopySentimentEnabledToEmotionEnabled < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
      SELECT 'ai_sentiment_emotion_enabled', value, data_type, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM site_settings
      WHERE name = 'ai_sentiment_enabled'
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
