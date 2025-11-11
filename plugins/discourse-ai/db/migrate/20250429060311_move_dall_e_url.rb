# frozen_string_literal: true
class MoveDallEUrl < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'ai_openai_image_generation_url'
      WHERE name = 'ai_openai_dall_e_3_url'
      AND NOT EXISTS (
        SELECT 1
        FROM site_settings
        WHERE name = 'ai_openai_image_generation_url')
    SQL

    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'ai_openai_dall_e_3_url'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
