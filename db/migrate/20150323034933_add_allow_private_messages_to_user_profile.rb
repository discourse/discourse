class AddAllowPrivateMessagesToUserProfile < ActiveRecord::Migration[4.2]
  def change
    add_column :user_profiles, :allow_private_messages, :boolean, default: true, null: false
  end
end
