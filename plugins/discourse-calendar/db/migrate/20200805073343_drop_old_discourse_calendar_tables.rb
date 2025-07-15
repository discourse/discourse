# frozen_string_literal: true

require "migration/table_dropper"

class DropOldDiscourseCalendarTables < ActiveRecord::Migration[6.0]
  def up
    if table_exists?(:discourse_calendar_post_events)
      Migration::TableDropper.execute_drop(:discourse_calendar_post_events)
    end

    if table_exists?(:discourse_calendar_invitees)
      Migration::TableDropper.execute_drop(:discourse_calendar_invitees)
    end
  end

  def down
    raise ActiveRecord::IrrelversibleMigration
  end
end
