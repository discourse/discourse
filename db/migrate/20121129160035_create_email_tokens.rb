# frozen_string_literal: true

class CreateEmailTokens < ActiveRecord::Migration[4.2]
  def change
    create_table :email_tokens do |t|
      t.integer :user_id, null: false
      t.string :email, null: false
      t.string :token, null: false
      t.boolean :confirmed, null: false, default: false
      t.boolean :expired, null: false, default: false
      t.timestamps null: false
    end
    add_index :email_tokens, :token, unique: true
  end
end
