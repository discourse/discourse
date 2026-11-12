# frozen_string_literal: true

class CreateDiscourseWorkflowsReviewableAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_reviewable_agents do |table|
      table.bigint :reviewable_id, null: false
      table.bigint :ai_agent_id, null: false
      table.datetime :created_at, null: false
    end

    add_index :discourse_workflows_reviewable_agents,
              %i[reviewable_id ai_agent_id],
              unique: true,
              name: "idx_dwf_reviewable_agents_on_reviewable_agent"
    add_index :discourse_workflows_reviewable_agents,
              %i[ai_agent_id reviewable_id],
              name: "idx_dwf_reviewable_agents_on_agent_reviewable"

    # Bulk reviewable deletion bypasses model callbacks; cascade avoids an orphan cleanup job.
    add_foreign_key :discourse_workflows_reviewable_agents, :reviewables, on_delete: :cascade
  end
end
