# frozen_string_literal: true

class AddStickyNotesToWorkflows < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_workflows_workflows, :sticky_notes, :jsonb, default: []
  end
end
