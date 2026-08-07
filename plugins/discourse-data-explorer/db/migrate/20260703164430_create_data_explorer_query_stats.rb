# frozen_string_literal: true
class CreateDataExplorerQueryStats < ActiveRecord::Migration[8.0]
  def change
    create_table :data_explorer_query_stats do |t|
      t.bigint :query_id, null: false
      t.date :date, null: false
      t.integer :total_runs, null: false, default: 0
    end

    add_index :data_explorer_query_stats, %i[query_id date], unique: true
  end
end
