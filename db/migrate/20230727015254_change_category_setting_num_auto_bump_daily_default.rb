# frozen_string_literal: true

class ChangeCategorySettingNumAutoBumpDailyDefault < ActiveRecord::Migration[7.0]
  def up
    change_column_default :category_settings, :num_auto_bump_daily, 0

    execute(<<~SQL)
      WITH custom_fields AS (
        SELECT
          category_id,
          MAX(
            CASE WHEN (name = 'require_topic_approval')
            THEN NULLIF(value, '') ELSE NULL END
          )::boolean AS require_topic_approval,
          MAX(
            CASE WHEN (name = 'require_reply_approval')
            THEN NULLIF(value, '') ELSE NULL END
          )::boolean AS require_reply_approval,
          MAX(
            CASE WHEN (name = 'num_auto_bump_daily')
            THEN NULLIF(value, '') ELSE NULL END
          )::integer AS num_auto_bump_daily,
          NOW() AS created_at,
          NOW() AS updated_at
        FROM category_custom_fields
        WHERE name IN (
          'require_topic_approval',
          'require_reply_approval',
          'num_auto_bump_daily'
        )
        GROUP BY category_id
      )
      INSERT INTO
        category_settings(
          category_id,
          require_topic_approval,
          require_reply_approval,
          num_auto_bump_daily,
          created_at,
          updated_at
        )
      SELECT * FROM custom_fields
      ON CONFLICT (category_id) DO
      UPDATE SET
        require_topic_approval = EXCLUDED.require_topic_approval,
        require_reply_approval = EXCLUDED.require_reply_approval,
        num_auto_bump_daily = EXCLUDED.num_auto_bump_daily,
        updated_at = NOW()
    SQL

    execute(<<~SQL)
      UPDATE category_settings
      SET num_auto_bump_daily = 0
      WHERE num_auto_bump_daily IS NULL;
    SQL
  end

  def down
    change_column_default :category_settings, :num_auto_bump_daily, nil

    execute(<<~SQL)
      UPDATE category_settings
      SET num_auto_bump_daily = NULL
      WHERE num_auto_bump_daily = 0;
    SQL
  end
end
