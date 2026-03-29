# frozen_string_literal: true

class CreateDiscourseWorkflowsCredentials < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_workflows_credentials do |t|
      t.string :name, limit: 128, null: false
      t.string :credential_type, limit: 64, null: false
      t.text :data, null: false
      t.timestamps
    end

    add_index :discourse_workflows_credentials, :credential_type
  end
end
