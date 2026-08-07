# frozen_string_literal: true
class CreateDiscourseWorkflowsExecutionStats < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_execution_stats do |t|
      t.bigint :workflow_id, null: false
      t.date :date, null: false
      t.integer :total_runs, null: false, default: 0
    end

    add_index :discourse_workflows_execution_stats,
              %i[workflow_id date],
              unique: true,
              name: "idx_dwf_execution_stats_on_workflow_id_and_date"
  end
end
