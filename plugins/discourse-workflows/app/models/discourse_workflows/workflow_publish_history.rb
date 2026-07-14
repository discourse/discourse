# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowPublishHistory < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_publish_history"

    EVENT_ACTIVATED = "activated"
    EVENT_DEACTIVATED = "deactivated"
    EVENTS = [EVENT_ACTIVATED, EVENT_DEACTIVATED].freeze

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"
    belongs_to :workflow_version,
               class_name: "DiscourseWorkflows::WorkflowVersion",
               foreign_key: "version_id",
               primary_key: "version_id",
               optional: true
    belongs_to :user, optional: true

    validates :workflow_id, presence: true
    validates :event, presence: true, inclusion: { in: EVENTS }
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflow_publish_history
#
#  id          :bigint           not null, primary key
#  event       :string(32)       not null
#  created_at  :datetime         not null
#  user_id     :integer
#  version_id  :string(36)
#  workflow_id :bigint           not null
#
# Indexes
#
#  idx_dwf_publish_history_on_workflow_created_at_id_desc  (workflow_id,created_at DESC,id DESC)
#
