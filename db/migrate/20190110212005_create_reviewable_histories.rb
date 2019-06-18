# frozen_string_literal: true

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

    # Migrate Created ReviewableUser History
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        0,
        0,
        r.created_by_id,
        r.created_at,
        r.created_at
      FROM reviewables AS r
      WHERE r.type = 'ReviewableUser'
    SQL

    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        1,
        1,
        r.created_by_id,
        r.created_at,
        r.created_at
      FROM reviewables AS r
      WHERE r.status = 1
        AND r.type = 'ReviewableUser'
    SQL
  end
end
