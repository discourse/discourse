# frozen_string_literal: true
class CreateClassificationResultsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :classification_results do |t|
      t.string :model_used, null: true
      t.string :classification_type, null: true
      t.integer :target_id, null: true
      t.string :target_type, null: true

      t.jsonb :classification, null: true
      t.timestamps
    end

    add_index :classification_results,
              %i[target_id target_type model_used],
              unique: true,
              name: "unique_classification_target_per_type"
  end
end
