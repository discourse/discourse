# frozen_string_literal: true

class SecureAssignmentTrackingPosts < ActiveRecord::Migration[7.2]
  def up
    # Keep the backfill independent of application model/schema caches. Include
    # historical unassignments and soft-deleted tracking posts, not just active
    # assignments. Cross-topic links cannot safely retain their old audience.
    execute <<~SQL
      CREATE TEMPORARY TABLE unsafe_assignment_tracking_posts ON COMMIT DROP AS
      SELECT tracking.id
      FROM posts tracking
      JOIN post_custom_fields link
        ON link.post_id = tracking.id AND link.name = 'action_code_post_id'
      LEFT JOIN posts target ON target.id::text = link.value
      WHERE tracking.action_code IN (
        'assigned_to_post', 'assigned_group_to_post',
        'unassigned_from_post', 'unassigned_group_from_post',
        'note_change', 'status_change', 'details_change'
      ) AND tracking.post_type IN (3, 4)
        AND (target.id IS NULL OR target.hidden OR target.deleted_at IS NOT NULL
             OR tracking.topic_id <> target.topic_id);

      DELETE FROM post_custom_fields
      WHERE post_id IN (SELECT id FROM unsafe_assignment_tracking_posts);

      DELETE FROM post_search_data
      WHERE post_id IN (SELECT id FROM unsafe_assignment_tracking_posts);

      DELETE FROM posts
      WHERE id IN (SELECT id FROM unsafe_assignment_tracking_posts);

      UPDATE posts tracking
      SET post_type = 4
      FROM post_custom_fields link, posts target
      WHERE link.post_id = tracking.id AND link.name = 'action_code_post_id'
        AND target.id::text = link.value
        AND tracking.action_code IN (
          'assigned_to_post', 'assigned_group_to_post',
          'unassigned_from_post', 'unassigned_group_from_post',
          'note_change', 'status_change', 'details_change'
        ) AND tracking.post_type = 3 AND target.post_type = 4
        AND NOT target.hidden AND target.deleted_at IS NULL
        AND tracking.topic_id = target.topic_id;

      DROP TABLE unsafe_assignment_tracking_posts;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
