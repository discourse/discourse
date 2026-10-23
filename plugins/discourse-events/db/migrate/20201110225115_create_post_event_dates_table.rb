# frozen_string_literal: true

class CreatePostEventDatesTable < ActiveRecord::Migration[6.0]
  def up
    create_table :discourse_calendar_post_event_dates do |t|
      t.integer :event_id
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :reminder_counter, default: 0
      t.datetime :event_will_start_sent_at
      t.datetime :event_started_sent_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :discourse_calendar_post_event_dates, :event_id
    add_index :discourse_calendar_post_event_dates, :finished_at
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
