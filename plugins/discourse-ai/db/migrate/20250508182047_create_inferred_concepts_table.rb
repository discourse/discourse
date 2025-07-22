# frozen_string_literal: true
class CreateInferredConceptsTable < ActiveRecord::Migration[7.2]
  def change
    create_table :inferred_concepts do |t|
      t.string :name, null: false
      t.timestamps
    end

    add_index :inferred_concepts, :name, unique: true
  end
end
