# frozen_string_literal: true
class AddIndexesForAssociatedAccountAvatars < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :user_associated_accounts,
                 :avatar_upload_id,
                 if_exists: true,
                 algorithm: :concurrently
    add_index :user_associated_accounts,
              :avatar_upload_id,
              where: "avatar_upload_id IS NOT NULL",
              algorithm: :concurrently

    remove_index :user_avatars,
                 :selected_user_associated_account_id,
                 if_exists: true,
                 algorithm: :concurrently
    add_index :user_avatars,
              :selected_user_associated_account_id,
              where: "selected_user_associated_account_id IS NOT NULL",
              algorithm: :concurrently
  end
end
