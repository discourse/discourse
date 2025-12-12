# frozen_string_literal: true

class CleanupOrphanedPmNotifications < ActiveRecord::Migration[8.0]
  def up
    # Delete all notifications for users who were removed from PMs.
    # This includes private_message, invited_to_private_message, mentioned,
    # quoted, replied, liked, etc. - any notification from a PM the user
    # can no longer access.
    execute <<~SQL
      DELETE FROM notifications
      WHERE id IN (
        SELECT n.id
        FROM notifications n
        INNER JOIN topics t ON t.id = n.topic_id
        WHERE t.archetype = 'private_message'
          AND NOT EXISTS (
            SELECT 1 FROM topic_allowed_users tau
            WHERE tau.topic_id = n.topic_id AND tau.user_id = n.user_id
          )
          AND NOT EXISTS (
            SELECT 1 FROM topic_allowed_groups tag
            INNER JOIN group_users gu ON gu.group_id = tag.group_id
            WHERE tag.topic_id = n.topic_id AND gu.user_id = n.user_id
          )
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
