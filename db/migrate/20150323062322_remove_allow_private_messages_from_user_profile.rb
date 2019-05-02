# frozen_string_literal: true

class RemoveAllowPrivateMessagesFromUserProfile < ActiveRecord::Migration[4.2]
  def change
    remove_column :user_profiles, :allow_private_messages
  end
end
