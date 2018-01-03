class RemoveUseUploadedAvatarFromUser < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :use_uploaded_avatar
  end
end
