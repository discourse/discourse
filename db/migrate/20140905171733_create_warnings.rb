# frozen_string_literal: true

class CreateWarnings < ActiveRecord::Migration[4.2]
  def change
    create_table :warnings do |t|
      t.references :topic, null: false
      t.references :user, null: false
      t.integer :created_by_id, null: false
      t.timestamps null: false
    end
    add_index :warnings, :user_id
    add_index :warnings, :topic_id, unique: true
  end
end
