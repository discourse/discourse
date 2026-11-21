# frozen_string_literal: true

class CreateAiReviewableSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_reviewable_suggestions do |t|
      t.references :reviewable,
                   null: false,
                   index: {
                     unique: true,
                   },
                   foreign_key: {
                     on_delete: :cascade,
                   }
      t.bigint :decision_model_id, null: false
      t.string :action_name, null: false
      t.float :confidence, null: false
      t.timestamps
    end
  end
end
