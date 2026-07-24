# frozen_string_literal: true

class AddTypeFieldToEventsReminders < ActiveRecord::Migration[7.0]
  def up
    reminders_query = <<~SQL
      SELECT id, reminders
      FROM discourse_post_event_events
      WHERE reminders IS NOT NULL
    SQL

    DB
      .query(reminders_query)
      .each do |event|
        refactored_reminders = []
        event
          .reminders
          .split(",") { |reminder| refactored_reminders.push(reminder.prepend("notification.")) }

        event_reminders = refactored_reminders.join(",")

        DB.exec(<<~SQL, id: event.id, reminders: event_reminders)
        UPDATE discourse_post_event_events
        SET reminders = :reminders
        WHERE id = :id
      SQL
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
