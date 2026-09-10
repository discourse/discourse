# frozen_string_literal: true
class CreateWorkflowSettingFields < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_workflow_setting_fields do |t|
      t.bigint :workflow_id, null: false
      t.string :key, null: false, limit: 100
      t.string :label, null: false, limit: 255
      t.string :description, limit: 500
      t.string :field_type, null: false, limit: 30
      t.jsonb :type_options, null: false, default: {}
      t.text :value
      t.timestamps null: false
    end

    add_index :discourse_workflows_workflow_setting_fields,
              %i[workflow_id key],
              unique: true,
              name: "idx_dwf_setting_fields_on_workflow_key"
  end
end
