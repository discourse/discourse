# frozen_string_literal: true

class BackfillAutoBumpCooldownCategorySetting < ActiveRecord::Migration[7.0]
  def up
    execute(<<~SQL)
      INSERT INTO
        category_settings(
          category_id,
          auto_bump_cooldown,
          created_at,
          updated_at
        )
      SELECT
        id,
        1,
        NOW(),
        NOW()
      FROM categories
      ON CONFLICT (category_id)
      DO
        UPDATE SET
          auto_bump_cooldown = 1,
          updated_at = NOW();
    SQL
  end
end
