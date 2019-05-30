# frozen_string_literal: true

require 'migration/column_dropper'

class CreateUserEmails < ActiveRecord::Migration[4.2]
  def up
    create_table :user_emails do |t|
      t.integer :user_id, null: false
      t.string :email, limit: 513, null: false
      t.boolean :primary, default: false, null: false
      t.timestamps null: false
    end

    add_index :user_emails, :user_id
    add_index :user_emails, [:user_id, :primary], unique: true

    execute "CREATE UNIQUE INDEX index_user_emails_on_email ON user_emails (lower(email));"

    execute <<~SQL
    INSERT INTO user_emails (
      id,
      user_id,
      email,
      "primary",
      created_at,
      updated_at
    ) SELECT
      id,
      id,
      email,
      'TRUE',
      created_at,
      updated_at
    FROM users
    SQL

    change_column_null :users, :email, true
    Migration::ColumnDropper.mark_readonly(:users, :email)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
