# frozen_string_literal: true

class CreateReviewableOutcomes < ActiveRecord::Migration[8.0]
  def change
    create_table :reviewable_outcomes do |t|
      t.bigint :reviewable_id, null: false
      t.string :outcome_source, null: false
      t.string :legal_basis, null: false
      t.string :restriction_type, array: true
      t.timestamps
    end

    add_index :reviewable_outcomes, %i[reviewable_id id]
  end
end
