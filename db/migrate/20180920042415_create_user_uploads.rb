# frozen_string_literal: true

class CreateUserUploads < ActiveRecord::Migration[5.2]
  def up
    create_table :user_uploads do |t|
      t.integer :upload_id, null: false
      t.integer :user_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :user_uploads, [:upload_id, :user_id], unique: true

    execute <<~SQL
      INSERT INTO user_uploads(upload_id, user_id, created_at)
      SELECT id, user_id, COALESCE(created_at, current_timestamp)
      FROM uploads
      WHERE user_id IS NOT NULL
    SQL
  end

  def down
    drop_table :user_uploads
  end
end
