# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowCallRun < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_call_runs"

    belongs_to :parent_execution,
               class_name: "DiscourseWorkflows::Execution",
               foreign_key: "parent_execution_id"
    belongs_to :child_execution,
               class_name: "DiscourseWorkflows::Execution",
               foreign_key: "child_execution_id",
               optional: true
    belongs_to :target_workflow,
               class_name: "DiscourseWorkflows::Workflow",
               foreign_key: "target_workflow_id"
    belongs_to :user, optional: true

    enum :status, { pending: 0, running: 1, success: 2, error: 3, waiting: 4 }

    scope :active, -> { where(status: statuses.values_at(:pending, :running, :waiting)) }

    def self.remove_execution_references(execution_ids)
      return if execution_ids.blank?

      where(child_execution_id: execution_ids).update_all(child_execution_id: nil)
      where(parent_execution_id: execution_ids).delete_all
    end

    def self.claim_pending(run)
      now = Time.current
      affected =
        where(id: run.id, status: statuses[:pending]).update_all(
          status: statuses[:running],
          updated_at: now,
        )
      return if affected.zero?

      run.status = :running
      run.updated_at = now
      run
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflow_call_runs
#
#  id                         :bigint           not null, primary key
#  error                      :text
#  parent_resume_token        :string(64)       not null
#  status                     :integer          default("pending"), not null
#  trigger_data               :jsonb            not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  child_execution_id         :bigint
#  parent_execution_id        :bigint           not null
#  parent_node_id             :string(100)      not null
#  target_workflow_id         :bigint           not null
#  target_workflow_version_id :string(36)       not null
#  user_id                    :bigint
#
# Indexes
#
#  idx_dwf_call_runs_on_child_execution_id   (child_execution_id) UNIQUE WHERE (child_execution_id IS NOT NULL)
#  idx_dwf_call_runs_on_parent_execution_id  (parent_execution_id)
#
