# frozen_string_literal: true

class CreateReviewableNotes < ActiveRecord::Migration[7.0]
  def change
    create_table :reviewable_notes do |t|
      t.references :reviewable, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.timestamps
    end

    add_index :reviewable_notes, %i[reviewable_id created_at]
  end
end
