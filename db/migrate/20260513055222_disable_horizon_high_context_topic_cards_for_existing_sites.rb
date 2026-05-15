# frozen_string_literal: true
class DisableHorizonHighContextTopicCardsForExistingSites < ActiveRecord::Migration[8.0]
  def up
    return if Migration::Helpers.new_site?

    execute <<~SQL
      INSERT INTO theme_settings(name, data_type, value, theme_id, created_at, updated_at)
      SELECT 'topic_card_high_context', 3, 'false', -2, NOW(), NOW()
      WHERE EXISTS(
        SELECT 1 FROM themes
        WHERE id = -2
      ) AND NOT EXISTS(
        SELECT 1 FROM theme_settings
        WHERE theme_id = -2 AND name = 'topic_card_high_context'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
