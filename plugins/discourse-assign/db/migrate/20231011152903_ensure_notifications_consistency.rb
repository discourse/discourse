# frozen_string_literal: true

class EnsureNotificationsConsistency < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      DELETE FROM notifications
      WHERE id IN (
        SELECT notifications.id FROM notifications
        LEFT OUTER JOIN assignments ON assignments.id = ((notifications.data::jsonb)->'assignment_id')::int
        WHERE (notification_type = 34 AND assignments.id IS NULL OR assignments.active = FALSE)
      )
    SQL

    DB.exec(<<~SQL)
      WITH tmp AS (
        SELECT
          assignments.assigned_to_id AS user_id,
          assignments.created_at,
          assignments.updated_at,
          assignments.topic_id,
          (
            CASE WHEN assignments.target_type = 'Topic' THEN 1
                 ELSE (SELECT posts.post_number FROM posts WHERE posts.id = assignments.target_id)
            END
          ) AS post_number,
          json_strip_nulls(json_build_object(
            'message', 'discourse_assign.assign_notification',
            'display_username', (SELECT users.username FROM users WHERE users.id = assignments.assigned_by_user_id),
            'topic_title', topics.title,
            'assignment_id', assignments.id
          ))::text AS data
        FROM assignments
        LEFT OUTER JOIN topics ON topics.deleted_at IS NULL AND topics.id = assignments.topic_id
        LEFT OUTER JOIN users ON users.id = assignments.assigned_to_id AND assignments.assigned_to_type = 'User'
        LEFT OUTER JOIN notifications ON ((data::jsonb)->'assignment_id')::int = assignments.id
        WHERE assignments.active = TRUE
          AND NOT (topics.id IS NULL OR users.id IS NULL)
          AND assignments.assigned_to_type = 'User'
          AND notifications.id IS NULL
      )
      INSERT INTO notifications (notification_type, high_priority, read, user_id, created_at, updated_at, topic_id, post_number, data)
        SELECT 34, TRUE, TRUE, tmp.* FROM tmp
    SQL

    DB.exec(<<~SQL)
      WITH tmp AS (
        SELECT
          users.id AS user_id,
          assignments.created_at,
          assignments.updated_at,
          assignments.topic_id,
          (
            CASE WHEN assignments.target_type = 'Topic' THEN 1
                 ELSE (SELECT posts.post_number FROM posts WHERE posts.id = assignments.target_id)
            END
          ) AS post_number,
          json_strip_nulls(json_build_object(
            'message', 'discourse_assign.assign_group_notification',
            'display_username', (SELECT groups.name FROM groups WHERE groups.id = assignments.assigned_to_id),
            'topic_title', topics.title,
            'assignment_id', assignments.id
          ))::text AS data
        FROM assignments
        LEFT OUTER JOIN topics ON topics.deleted_at IS NULL AND topics.id = assignments.topic_id
        LEFT OUTER JOIN groups ON groups.id = assignments.assigned_to_id AND assignments.assigned_to_type = 'Group'
        LEFT OUTER JOIN group_users ON groups.id = group_users.group_id
        LEFT OUTER JOIN users ON users.id = group_users.user_id
        LEFT OUTER JOIN notifications ON ((data::jsonb)->'assignment_id')::int = assignments.id AND notifications.user_id = users.id
        WHERE assignments.active = TRUE
          AND NOT (topics.id IS NULL OR groups.id IS NULL)
          AND assignments.assigned_to_type = 'Group'
          AND notifications.id IS NULL
      )
      INSERT INTO notifications (notification_type, high_priority, read, user_id, created_at, updated_at, topic_id, post_number, data)
        SELECT 34, TRUE, TRUE, tmp.* FROM tmp
    SQL
  end

  def down
  end
end
