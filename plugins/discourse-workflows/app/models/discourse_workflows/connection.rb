# frozen_string_literal: true

module DiscourseWorkflows
  class Connection < ActiveRecord::Base
    self.table_name = "discourse_workflows_connections"

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow", foreign_key: "workflow_id"
    belongs_to :source_node, class_name: "DiscourseWorkflows::Node", foreign_key: "source_node_id"
    belongs_to :target_node, class_name: "DiscourseWorkflows::Node", foreign_key: "target_node_id"
  end
end

# == Schema Information
#
# Table name: discourse_workflows_connections
#
#  id             :bigint           not null, primary key
#  source_output  :string           default("main"), not null
#  target_input   :string           default("main"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  source_node_id :integer          not null
#  target_node_id :integer          not null
#  workflow_id    :integer          not null
#
# Indexes
#
#  index_discourse_workflows_connections_on_source_node_id  (source_node_id)
#  index_discourse_workflows_connections_on_target_node_id  (target_node_id)
#  index_discourse_workflows_connections_on_workflow_id     (workflow_id)
#
