# frozen_string_literal: true

require 'migration/column_dropper'

class CreatePostReplyKeys < ActiveRecord::Migration[5.2]
  def up
    create_table :post_reply_keys do |t|
      t.integer :user_id, null: false
      t.integer :post_id, null: false
      t.uuid :reply_key, null: false
      t.timestamps null: false
    end

    add_index :post_reply_keys, :reply_key, unique: true

    Migration::ColumnDropper.mark_readonly(:email_logs, :reply_key)

    sql = <<~SQL
    DELETE FROM email_logs
    WHERE id IN (
      SELECT id
      FROM (
        SELECT
          id,
          ROW_NUMBER() OVER(PARTITION BY post_id, user_id ORDER BY id DESC) AS row_num
        FROM email_logs
      ) t
      WHERE t.row_num > 1
    )
    SQL

    execute(sql)

    sql = <<~SQL
    INSERT INTO post_reply_keys(
      user_id, post_id, reply_key, updated_at, created_at
    ) SELECT
        user_id,
        post_id,
        reply_key,
        updated_at,
        created_at
      FROM email_logs
      WHERE reply_key IS NOT NULL AND post_id IS NOT NULL AND user_id IS NOT NULL
    SQL

    execute(sql)

    add_index :post_reply_keys, [:user_id, :post_id], unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
