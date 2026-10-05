# frozen_string_literal: true
class AddAssociatedAccountAvatars < ActiveRecord::Migration[8.0]
  def change
    add_column :user_associated_accounts, :avatar_upload_id, :integer
    add_column :user_avatars, :selected_user_associated_account_id, :bigint
  end
end
