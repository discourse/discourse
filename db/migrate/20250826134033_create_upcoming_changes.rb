# frozen_string_literal: true
class CreateUpcomingChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :upcoming_changes do |t|
      t.string :identifier, null: false, index: { unique: true }
      t.string :description, null: false
      t.boolean :enabled, null: false, default: false
      t.bigint :enabled_by_id, null: true, index: true
      t.integer :status, null: false, default: 0
      t.integer :risk_level, null: false, default: 0
      t.integer :type, null: false, default: 0
      t.string :plugin_identifier, null: true, index: true
      t.integer :meta_topic_id, null: true

      t.timestamps
    end
  end
end
