# frozen_string_literal: true

class UpdateCategorySettingApprovalValues < ActiveRecord::Migration[7.0]
  def up
    change_column_default :category_settings, :require_topic_approval, false
    change_column_default :category_settings, :require_reply_approval, false

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
          NOW() AS created_at,
          NOW() AS updated_at
        FROM category_custom_fields
        WHERE name IN (
          'require_topic_approval',
          'require_reply_approval'
        )
        GROUP BY category_id
      )
      INSERT INTO
        category_settings(
          category_id,
          require_topic_approval,
          require_reply_approval,
          created_at,
          updated_at
        )
      SELECT * FROM custom_fields
      ON CONFLICT (category_id) DO
      UPDATE SET
        require_topic_approval = EXCLUDED.require_topic_approval,
        require_reply_approval = EXCLUDED.require_reply_approval,
        updated_at = NOW()
    SQL

    execute(<<~SQL)
      UPDATE category_settings
      SET require_topic_approval = false
      WHERE require_topic_approval IS NULL;
    SQL

    execute(<<~SQL)
      UPDATE category_settings
      SET require_reply_approval = false
      WHERE require_reply_approval IS NULL;
    SQL
  end

  def down
    change_column_default :category_settings, :require_topic_approval, nil
    change_column_default :category_settings, :require_reply_approval, nil

    execute(<<~SQL)
      UPDATE category_settings
      SET require_topic_approval = NULL
      WHERE require_topic_approval = false;
    SQL

    execute(<<~SQL)
      UPDATE category_settings
      SET require_reply_approval = NULL
      WHERE require_reply_approval = false;
    SQL
  end
end
