# frozen_string_literal: true

class BackfillLivestreamFromTag < ActiveRecord::Migration[8.0]
  # Before livestreams became a boolean on the event
  # (`discourse_post_event_events.livestream`), a topic behaved as a livestream
  # when `livestream_enabled` was on and the topic was tagged "livestream".
  # Backfill the new column for those existing topics so they keep livestreaming after upgrade.
  # Livestream is now read from the topic's first-post event (topic.first_post.event.livestream?)
  # so only first-post events are updated.
  def up
    livestream_enabled =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'livestream_enabled' AND value = 't'",
      )
    return if livestream_enabled.blank?

    execute <<~SQL
      UPDATE discourse_post_event_events e
      SET livestream = true
      FROM posts p
      JOIN topic_tags tt ON tt.topic_id = p.topic_id
      JOIN tags t ON t.id = tt.tag_id
      WHERE e.id = p.id
        AND p.post_number = 1
        AND e.livestream = false
        AND t.name = 'livestream'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
