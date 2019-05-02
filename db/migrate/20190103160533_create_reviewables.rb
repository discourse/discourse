# frozen_string_literal: true

class CreateReviewables < ActiveRecord::Migration[5.2]
  def change
    create_table :reviewables do |t|
      t.string :type, null: false
      t.integer :status, null: false, default: 0
      t.integer :created_by_id, null: false

      # Who can review this item? Moderators always can
      t.boolean :reviewable_by_moderator, null: false, default: false
      t.integer :reviewable_by_group_id, null: true

      # On some high traffic sites they want things in review to be claimed
      # so that two people don't work on the same thing.
      t.integer :claimed_by_id, null: true

      # For filtering
      t.integer :category_id, null: true
      t.integer :topic_id, null: true
      t.float :score, null: false, default: 0
      t.boolean :potential_spam, null: false, default: false

      # Polymorphic relation of reviewable thing
      t.integer :target_id, null: true
      t.string :target_type, null: true
      t.integer :target_created_by_id, null: true

      t.json :payload, null: true

      # Helps us prevent simultaneous updates
      t.integer :version, null: false, default: 0

      t.datetime :latest_score, null: true
      t.timestamps
    end

    add_index :reviewables, :status
    add_index :reviewables, [:status, :type]
    add_index :reviewables, [:status, :score]
    add_index :reviewables, [:type, :target_id], unique: true
  end
end
