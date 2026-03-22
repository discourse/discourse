# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionStep < ActiveRecord::Base
    self.table_name = "discourse_workflows_execution_steps"

    belongs_to :execution, class_name: "DiscourseWorkflows::Execution", foreign_key: "execution_id"
    belongs_to :node, class_name: "DiscourseWorkflows::Node", foreign_key: "node_id"

    enum :status,
         { pending: 0, running: 1, success: 2, error: 3, skipped: 4, filtered: 5, waiting: 6 }

    scope :ordered, -> { order(:position) }
  end
end

# == Schema Information
#
# Table name: discourse_workflows_execution_steps
#
#  id           :bigint           not null, primary key
#  error        :text
#  finished_at  :datetime
#  input        :jsonb
#  metadata     :jsonb
#  node_name    :string
#  node_type    :string
#  output       :jsonb
#  position     :integer          default(0), not null
#  started_at   :datetime
#  status       :integer          default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  execution_id :integer          not null
#  node_id      :integer          not null
#
# Indexes
#
#  index_discourse_workflows_execution_steps_on_execution_id  (execution_id)
#  index_discourse_workflows_execution_steps_on_node_id       (node_id)
#
