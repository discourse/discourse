# frozen_string_literal: true

class DropStickyNotesFromWorkflows < ActiveRecord::Migration[7.2]
  def up
    remove_column :discourse_workflows_workflows, :sticky_notes
  end

  def down
    add_column :discourse_workflows_workflows, :sticky_notes, :jsonb, default: []
  end
end
