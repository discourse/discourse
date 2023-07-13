# frozen_string_literal: true

class AddDefaultCalendarToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :default_calendar, :integer, default: 0, null: false
    add_index :user_options, %i[user_id default_calendar]
  end
end
