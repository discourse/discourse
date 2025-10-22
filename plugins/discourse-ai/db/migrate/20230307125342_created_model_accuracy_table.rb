# frozen_string_literal: true

class CreatedModelAccuracyTable < ActiveRecord::Migration[7.0]
  def change
    create_table :model_accuracies do |t|
      t.string :model, null: false
      t.string :classification_type, null: false
      t.integer :flags_agreed, null: false, default: 0
      t.integer :flags_disagreed, null: false, default: 0

      t.timestamps
    end

    add_index :model_accuracies, %i[model], unique: true
  end
end
