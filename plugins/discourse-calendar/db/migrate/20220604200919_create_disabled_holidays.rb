# frozen_string_literal: true

class CreateDisabledHolidays < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_calendar_disabled_holidays do |t|
      t.string :holiday_name, null: false
      t.string :region_code, null: false
      t.boolean :disabled, null: false, default: true

      t.timestamps
    end

    add_index :discourse_calendar_disabled_holidays,
              %i[holiday_name region_code],
              name: "index_disabled_holidays_on_holiday_name_and_region_code"
  end
end
