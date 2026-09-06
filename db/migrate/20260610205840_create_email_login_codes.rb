# frozen_string_literal: true
class CreateEmailLoginCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :email_login_codes do |t|
      t.string :email, null: false
      t.string :code_hash, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :email_login_codes, "lower(email)"
    add_index :email_login_codes, :expires_at
  end
end
