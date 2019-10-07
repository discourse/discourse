# frozen_string_literal: true

class CreateTriggersTable < ActiveRecord::Migration[5.2]
  def change
    create_table :discourse_automation_triggers do |t|
      t.integer :identifier, null: false
      t.jsonb :options, null: false, default: {}
      t.references :workflow
      t.timestamps null: false
    end
  end
end
