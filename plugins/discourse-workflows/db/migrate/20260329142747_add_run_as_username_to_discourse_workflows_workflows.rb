# frozen_string_literal: true

class AddRunAsUsernameToDiscourseWorkflowsWorkflows < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_workflows_workflows, :run_as_username, :string, default: "system"
  end
end
