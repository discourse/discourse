# frozen_string_literal: true

class RenameDiscourseWorkflowsEnabledSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE site_settings SET name = 'enable_discourse_workflows' WHERE name = 'discourse_workflows_enabled'"
  end

  def down
    execute "UPDATE site_settings SET name = 'discourse_workflows_enabled' WHERE name = 'enable_discourse_workflows'"
  end
end
