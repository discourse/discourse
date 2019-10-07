# frozen_string_literal: true

class CreatePlansTable < ActiveRecord::Migration[5.2]
  def change
    create_table :discourse_automation_plans do |t|
      t.integer :identifier, null: false
      t.integer :delay, null: false, default: 0
      t.jsonb :options, null: false, default: {}
      t.references :workflow
      t.timestamps null: false
    end
  end
end
