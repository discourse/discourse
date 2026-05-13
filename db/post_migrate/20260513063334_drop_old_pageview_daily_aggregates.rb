# frozen_string_literal: true

class DropOldPageviewDailyAggregates < ActiveRecord::Migration[8.0]
  def up
    drop_table :pageview_daily_aggregates, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
