# frozen_string_literal: true

class CreateUserVisitDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :user_visit_daily_rollups do |t|
      t.date :date, null: false
      t.bigint :dau, null: false
      t.bigint :mau, null: false
    end

    add_index :user_visit_daily_rollups, :date, unique: true
  end
end
