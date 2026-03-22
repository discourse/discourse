# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflows"

    has_many :nodes,
             class_name: "DiscourseWorkflows::Node",
             foreign_key: "workflow_id",
             dependent: :destroy
    has_many :connections,
             class_name: "DiscourseWorkflows::Connection",
             foreign_key: "workflow_id",
             dependent: :destroy
    has_many :executions,
             class_name: "DiscourseWorkflows::Execution",
             foreign_key: "workflow_id",
             dependent: :destroy

    belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
    belongs_to :updated_by, class_name: "User", foreign_key: "updated_by_id", optional: true

    validates :name, presence: true, length: { maximum: 100 }

    scope :enabled, -> { where(enabled: true) }

    def trigger_node
      nodes.find_by("type LIKE ?", "trigger:%")
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflows
#
#  id                :bigint           not null, primary key
#  allowed_group_ids :integer          default([]), is an Array
#  enabled           :boolean          default(FALSE), not null
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  created_by_id     :integer          not null
#  updated_by_id     :integer
#
# Indexes
#
#  index_discourse_workflows_workflows_on_created_by_id  (created_by_id)
#  index_discourse_workflows_workflows_on_updated_by_id  (updated_by_id)
#
