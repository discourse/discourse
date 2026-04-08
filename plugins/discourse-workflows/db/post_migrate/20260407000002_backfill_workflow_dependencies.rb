# frozen_string_literal: true

class BackfillWorkflowDependencies < ActiveRecord::Migration[7.2]
  def up
    DiscourseWorkflows::Workflow.find_each do |workflow|
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
    end
  end

  def down
    execute "DELETE FROM discourse_workflows_workflow_dependencies"
  end
end
