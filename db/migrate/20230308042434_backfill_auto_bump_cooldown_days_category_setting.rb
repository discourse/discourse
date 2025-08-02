# frozen_string_literal: true

class BackfillAutoBumpCooldownDaysCategorySetting < ActiveRecord::Migration[7.0]
  def up
    execute(<<~SQL)
      INSERT INTO
        category_settings(
          category_id,
          auto_bump_cooldown_days,
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
          auto_bump_cooldown_days = 1,
          updated_at = NOW();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
