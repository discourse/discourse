# frozen_string_literal: true

module DiscourseWorkflows
  class Execution < ActiveRecord::Base
    self.table_name = "discourse_workflows_executions"

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow", foreign_key: "workflow_id"

    has_many :steps,
             class_name: "DiscourseWorkflows::ExecutionStep",
             foreign_key: "execution_id",
             dependent: :destroy

    enum :status, { pending: 0, running: 1, success: 2, error: 3, waiting: 4 }

    scope :recent, -> { order(created_at: :desc) }
  end
end

# == Schema Information
#
# Table name: discourse_workflows_executions
#
#  id              :bigint           not null, primary key
#  context         :jsonb
#  error           :text
#  finished_at     :datetime
#  started_at      :datetime
#  status          :integer          default("pending"), not null
#  trigger_data    :jsonb
#  waiting_config  :jsonb            not null
#  waiting_until   :datetime
#  workflow_data   :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  trigger_node_id :integer
#  waiting_node_id :integer
#  workflow_id     :integer          not null
#
# Indexes
#
#  idx_executions_waiting_until                             (waiting_until) WHERE ((waiting_until IS NOT NULL) AND (status = 4))
#  index_discourse_workflows_executions_on_status           (status)
#  index_discourse_workflows_executions_on_waiting_node_id  (waiting_node_id)
#  index_discourse_workflows_executions_on_workflow_id      (workflow_id)
#
