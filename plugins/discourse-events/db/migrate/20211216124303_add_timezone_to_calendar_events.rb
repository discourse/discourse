# frozen_string_literal: true

class AddTimezoneToCalendarEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :calendar_events, :timezone, :string
  end
end
