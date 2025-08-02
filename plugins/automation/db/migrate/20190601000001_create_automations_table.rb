# frozen_string_literal: true

class CreateAutomationsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :discourse_automation_automations do |t|
      t.string :name, null: false
      t.string :script, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps null: false
    end

    create_table :discourse_automation_fields do |t|
      t.integer :automation_id, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :component, null: false
      t.string :name, null: false
      t.timestamps null: false
    end

    create_table :discourse_automation_triggers do |t|
      t.integer :automation_id, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :name, null: false
      t.timestamps null: false
    end

    create_table :discourse_automation_pending_automations do |t|
      t.integer :automation_id, null: false
      t.datetime :execute_at, null: false
      t.timestamps null: false
    end
  end
end
