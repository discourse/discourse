class AddUploadedAvatarIdIndexToUsers < ActiveRecord::Migration
  def change
    add_index :users, :uploaded_avatar_id
  end
end
