class RemoveUseUploadedAvatarFromUser < ActiveRecord::Migration
  def change
    remove_column :users, :use_uploaded_avatar
  end
end
