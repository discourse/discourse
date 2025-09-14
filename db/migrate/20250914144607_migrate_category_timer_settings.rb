# frozen_string_literal: true
class MigrateCategoryTimerSettings < ActiveRecord::Migration[8.0]
  def up
    close_type = BaseTimer.types[:close]
    system_user_id = Discourse.system_user.id

    execute <<~SQL
      INSERT INTO topic_timers (
        based_on_last_post,
        deleted_at,
        duration_minutes,
        execute_at,
        public_type,
        status_type,
        type,
        created_at,
        updated_at,
        category_id,
        deleted_by_id,
        timerable_id,
        user_id
      )
      SELECT
        auto_close_based_on_last_post,
        NULL,
        auto_close_hours * 60,
        CURRENT_TIMESTAMP,
        TRUE,
        #{close_type},
        'CategoryDefaultTimer',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        NULL,
        NULL,
        id,
        #{system_user_id}             
      FROM categories
      WHERE auto_close_hours IS NOT NULL;
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM topic_timers
      WHERE type = 'CategoryDefaultTimer';
    SQL
  end
end
