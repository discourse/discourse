# frozen_string_literal: true

class PopulateCategorySettings < ActiveRecord::Migration[7.0]
  def up
    execute(<<~SQL)
      INSERT INTO
        category_settings(
          category_id,
          require_topic_approval,
          require_reply_approval,
          num_auto_bump_daily,
          created_at,
          updated_at
        )
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
      GROUP BY category_id;
    SQL
  end

  def down
    execute(<<~SQL)
      TRUNCATE category_settings;
    SQL
  end
end
