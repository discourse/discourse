class ArchiveSystemMessagesWithNoReplies < ActiveRecord::Migration
  def up
    # backdate archival of system messages send on behalf of site_contact_user
    execute <<SQL

    INSERT INTO user_archived_messages (user_id, topic_id, created_at, updated_at)
    SELECT p.user_id, p.topic_id, p.created_at, p.updated_at
    FROM posts p
    JOIN topics t ON t.id = p.topic_id
    LEFT JOIN user_archived_messages um ON um.user_id = p.user_id AND um.topic_id = p.topic_id
    WHERE t.subtype = 'system_message' AND
          t.posts_count = 1 AND
          t.archetype = 'private_message' AND
          um.id IS NULL AND
          p.user_id IS NOT NULL AND
          p.topic_id IS NOT NULL AND
          p.post_number = 1
SQL

  end

  def down
  end
end
