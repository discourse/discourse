# frozen_string_literal: true

class CreateWorkflowsTable < ActiveRecord::Migration[5.2]
  def change
    create_table :discourse_automation_workflows do |t|
      t.string :name, null: false
      t.timestamps null: false
    end
  end
end
