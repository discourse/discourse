# frozen_string_literal: true

class CreateWebHookEventsDailyAggregates < ActiveRecord::Migration[7.0]
  def change
    create_table :web_hook_events_daily_aggregates do |t|
      t.belongs_to :web_hook, null: false, index: true
      t.date :date
      t.integer :successful_events_id, array: true
      t.integer :failed_events_id, array: true
      t.integer :mean_duration, default: 0

      t.timestamps
    end
  end
end
