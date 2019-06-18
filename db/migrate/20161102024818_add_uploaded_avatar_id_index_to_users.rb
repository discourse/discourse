# frozen_string_literal: true

class AddUploadedAvatarIdIndexToUsers < ActiveRecord::Migration[4.2]
  def change
    add_index :users, :uploaded_avatar_id
  end
end
