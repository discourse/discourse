# frozen_string_literal: true

require 'migration/column_dropper'

class CreateSkippedEmailLogs < ActiveRecord::Migration[5.2]
  def change
    create_table :skipped_email_logs do |t|
      t.string :email_type, null: false
      t.string :to_address, null: false
      t.integer :user_id
      t.integer :post_id
      t.integer :reason_type, null: false
      t.text :custom_reason
      t.timestamps
    end

    add_index :skipped_email_logs, :created_at
    add_index :skipped_email_logs, :user_id
    add_index :skipped_email_logs, :post_id
    add_index :skipped_email_logs, :reason_type

    sql = <<~SQL
    INSERT INTO skipped_email_logs (
      email_type,
      to_address,
      user_id,
      post_id,
      reason_type,
      custom_reason,
      created_at,
      updated_at
    ) SELECT
        email_type,
        to_address,
        user_id,
        post_id,
        1,
        skipped_reason,
        created_at,
        updated_at
      FROM email_logs
      WHERE skipped IS TRUE
    SQL

    execute(sql)

    Migration::ColumnDropper.mark_readonly('email_logs', 'skipped_reason')
  end
end
