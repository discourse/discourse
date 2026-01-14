# frozen_string_literal: true

class RefactorReminders < ActiveRecord::Migration[6.0]
  def up
    add_column :discourse_post_event_events, :reminders, :string
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
