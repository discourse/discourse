# frozen_string_literal: true

class FixPostEventTimezones < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE discourse_post_event_events
      SET
        original_starts_at = (original_starts_at::timestamp AT TIME ZONE timezone),
        original_ends_at = (original_ends_at::timestamp AT TIME ZONE timezone)
      WHERE timezone IS NOT NULL;
    SQL

    execute <<~SQL
      UPDATE discourse_calendar_post_event_dates
      SET
        starts_at = (starts_at::timestamp AT TIME ZONE timezone),
        ends_at = (ends_at::timestamp AT TIME ZONE timezone)
      FROM discourse_post_event_events
      WHERE discourse_post_event_events.id = discourse_calendar_post_event_dates.event_id
      AND discourse_post_event_events.timezone IS NOT NULL
    SQL

    execute <<~SQL
      UPDATE topic_custom_fields
      SET value = (value::timestamp AT TIME ZONE discourse_post_event_events.timezone) AT TIME ZONE 'UTC'
      FROM discourse_post_event_events
      JOIN posts ON discourse_post_event_events.id = posts.id
      WHERE discourse_post_event_events.timezone IS NOT NULL
      AND topic_custom_fields.topic_id = posts.topic_id
      AND topic_custom_fields.name IN ('TopicEventStartsAt', 'TopicEventEndsAt')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
