# frozen_string_literal: true

class MigrateSolvedAutoCloseHoursToDays < ActiveRecord::Migration[7.2]
  def up
    # Migrate category_custom_fields: hours → days (rounded to nearest day, minimum 1 for positive values)
    execute <<~SQL
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT category_id,
             'solved_topics_auto_close_days',
             GREATEST(1, ROUND(value::numeric / 24.0, 0))::integer,
             NOW(),
             NOW()
        FROM category_custom_fields
       WHERE name = 'solved_topics_auto_close_hours'
         AND value::numeric > 0
         AND NOT EXISTS (
           SELECT 1
             FROM category_custom_fields cf2
            WHERE cf2.category_id = category_custom_fields.category_id
              AND cf2.name = 'solved_topics_auto_close_days'
         )
    SQL

    # Migrate site_settings: hours → days (rounded to nearest day, minimum 1 for positive values)
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'solved_topics_auto_close_days',
             data_type,
             GREATEST(1, ROUND(value::numeric / 24.0, 0))::integer,
             NOW(),
             NOW()
        FROM site_settings
       WHERE name = 'solved_topics_auto_close_hours'
         AND value::numeric > 0
         AND NOT EXISTS (
           SELECT 1
             FROM site_settings ss2
            WHERE ss2.name = 'solved_topics_auto_close_days'
         )
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM category_custom_fields WHERE name = 'solved_topics_auto_close_days'
    SQL

    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'solved_topics_auto_close_days'
    SQL
  end
end
