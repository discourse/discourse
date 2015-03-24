class RemoveAllowPrivateMessagesFromUserProfile < ActiveRecord::Migration
  def change
    remove_column :user_profiles, :allow_private_messages
  end
end
