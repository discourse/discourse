class AddUploadIdToUserExports < ActiveRecord::Migration[5.1]
  def change
    add_column :user_exports, :upload_id, :integer
  end
end
