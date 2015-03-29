class RemoveUploadedAvatarTemplateFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :uploaded_avatar_template
  end
end
