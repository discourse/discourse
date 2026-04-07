# frozen_string_literal: true

class DropAllowedGroupIdsFromWorkflows < ActiveRecord::Migration[7.2]
  def up
    remove_column :discourse_workflows_workflows, :allowed_group_ids
  end

  def down
    add_column :discourse_workflows_workflows, :allowed_group_ids, :integer, array: true, default: []
  end
end
