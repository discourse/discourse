class CreateReviewableHistories < ActiveRecord::Migration[5.2]
  def change
    create_table :reviewable_histories do |t|
      t.integer :reviewable_id, null: false
      t.integer :reviewable_history_type, null: false
      t.integer :status, null: false
      t.integer :created_by_id, null: false
      t.json    :edited, null: true
      t.timestamps
    end

    add_index :reviewable_histories, :reviewable_id
  end
end
