# frozen_string_literal: true
class RemoveUserPasswordsIndexes < ActiveRecord::Migration[7.1]
  def change
    remove_index :user_passwords, %i[user_id password_hash], unique: true

    remove_index :user_passwords,
                 %i[user_id password_expired_at password_hash],
                 name: "idx_user_passwords_on_user_id_and_expired_at_and_hash"
  end
end
