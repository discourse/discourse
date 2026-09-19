# frozen_string_literal: true

class PopulateMissingSolvedTopicsAutoCloseHours < ActiveRecord::Migration[8.0]
  def up
    return if !Migration::Helpers.existing_site?

    execute <<~SQL
      UPDATE category_custom_fields auto_close
      SET value = '0', updated_at = NOW()
      WHERE auto_close.name = 'solved_topics_auto_close_hours'
        AND auto_close.value IS NULL
        AND EXISTS (
          SELECT 1
          FROM categories
          WHERE categories.id = auto_close.category_id
            AND (
              EXISTS (
                SELECT 1
                FROM site_settings
                WHERE name = 'allow_solved_on_all_topics' AND value = 't'
              )
              OR EXISTS (
                SELECT 1
                FROM category_custom_fields enabled_solved
                WHERE enabled_solved.category_id = categories.id
                  AND enabled_solved.name = 'enable_accepted_answers'
                  AND enabled_solved.value = 'true'
              )
            )
        )
    SQL

    execute <<~SQL
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT categories.id, 'solved_topics_auto_close_hours', '0', NOW(), NOW()
      FROM categories
      WHERE
        (
          EXISTS (
            SELECT 1
            FROM site_settings
            WHERE name = 'allow_solved_on_all_topics' AND value = 't'
          )
          OR EXISTS (
            SELECT 1
            FROM category_custom_fields enabled_solved
            WHERE enabled_solved.category_id = categories.id
              AND enabled_solved.name = 'enable_accepted_answers'
              AND enabled_solved.value = 'true'
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM category_custom_fields existing
          WHERE existing.category_id = categories.id
            AND existing.name = 'solved_topics_auto_close_hours'
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
