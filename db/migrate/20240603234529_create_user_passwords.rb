# frozen_string_literal: true

class CreateUserPasswords < ActiveRecord::Migration[7.0]
  def change
    create_table :user_passwords, id: :integer do |t|
      t.integer :user_id, null: false
      t.string :password_hash, limit: 64, null: false
      t.string :password_salt, limit: 32, null: false
      t.string :password_algorithm, limit: 64, null: false
      t.datetime :password_expired_at, null: true

      t.timestamps
    end

    add_index :user_passwords, %i[user_id], unique: true, where: "password_expired_at IS NULL"

    add_index :user_passwords, %i[user_id password_hash], unique: true

    add_index :user_passwords,
              %i[user_id password_expired_at password_hash],
              name: "idx_user_passwords_on_user_id_and_expired_at_and_hash"
  end
end
