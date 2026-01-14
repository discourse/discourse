# frozen_string_literal: true

require "migration/table_dropper"

class RenameTablesToDiscoursePostEvent < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:discourse_post_event_events)
      Migration::TableDropper.read_only_table(:discourse_calendar_post_events)

      execute <<~SQL
        CREATE TABLE discourse_post_event_events
        (LIKE discourse_calendar_post_events INCLUDING ALL);
      SQL

      execute <<~SQL
        INSERT INTO discourse_post_event_events
        SELECT *
        FROM discourse_calendar_post_events
      SQL

      execute <<~SQL
        ALTER SEQUENCE discourse_calendar_post_events_id_seq
        RENAME TO discourse_post_event_events_id_seq
      SQL

      execute <<~SQL
        ALTER SEQUENCE discourse_post_event_events_id_seq
        OWNED BY discourse_post_event_events.id
      SQL
    end

    unless table_exists?(:discourse_post_event_invitees)
      Migration::TableDropper.read_only_table(:discourse_calendar_invitees)

      execute <<~SQL
        CREATE TABLE discourse_post_event_invitees
        (LIKE discourse_calendar_invitees INCLUDING ALL)
      SQL

      execute <<~SQL
        INSERT INTO discourse_post_event_invitees
        SELECT *
        FROM discourse_calendar_invitees
      SQL

      execute <<~SQL
        ALTER SEQUENCE discourse_calendar_invitees_id_seq
        RENAME TO discourse_post_event_invitees_id_seq
      SQL

      execute <<~SQL
        ALTER SEQUENCE discourse_post_event_invitees_id_seq
        OWNED BY discourse_post_event_invitees.id
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
