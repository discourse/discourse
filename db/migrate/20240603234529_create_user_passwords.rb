# frozen_string_literal: true

class CreateUserPasswords < ActiveRecord::Migration[7.0]
  def change
    create_table :user_passwords, id: :integer do |t|
      t.integer :user_id, null: false
      t.string :hash, limit: 64, null: false
      t.string :salt, limit: 32, null: false
      t.string :algorithm, limit: 64, null: false
      t.datetime :expired_at, null: true

      t.timestamps
    end

    add_index :user_passwords, %i[user_id], unique: true, where: "expired_at IS NULL"
    add_index :user_passwords, %i[user_id expired_at hash]
  end
end
