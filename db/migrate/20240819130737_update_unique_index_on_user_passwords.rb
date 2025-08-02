# frozen_string_literal: true
class UpdateUniqueIndexOnUserPasswords < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index :user_passwords,
                 %i[user_id],
                 unique: true,
                 where: "password_expired_at IS NULL",
                 algorithm: :concurrently,
                 if_exists: true

    add_index :user_passwords,
              %i[user_id],
              unique: true,
              algorithm: :concurrently,
              if_not_exists: true
  end
end
