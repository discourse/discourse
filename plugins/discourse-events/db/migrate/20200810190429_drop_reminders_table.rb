# frozen_string_literal: true

class DropRemindersTable < ActiveRecord::Migration[6.0]
  def up
    drop_table :discourse_post_event_reminders
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
