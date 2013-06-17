class RenameShaAndExtColumns < ActiveRecord::Migration
  def up
    rename_column :optimized_images, :sha, :sha1
    change_column :optimized_images, :sha1, :string, limit: 40
    rename_column :optimized_images, :ext, :extension
    change_column :optimized_images, :extension, :string, limit: 10
  end

  def down
    change_column :optimized_images, :extension, :string, limit: 255
    rename_column :optimized_images, :extension, :ext
    change_column :optimized_images, :sha1, :string, limit: 255
    rename_column :optimized_images, :sha1, :sha
  end
end
