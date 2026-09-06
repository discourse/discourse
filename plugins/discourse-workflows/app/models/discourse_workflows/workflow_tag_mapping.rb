# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTagMapping < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_tags"

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"
    belongs_to :workflow_tag, class_name: "DiscourseWorkflows::WorkflowTag"
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflow_tags
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  workflow_id     :bigint           not null
#  workflow_tag_id :bigint           not null
#
# Indexes
#
#  idx_dwf_workflow_tags_on_tag_workflow  (workflow_tag_id,workflow_id) UNIQUE
#  idx_dwf_workflow_tags_on_workflow_tag  (workflow_id,workflow_tag_id) UNIQUE
#
