class AddShaToUploads < ActiveRecord::Migration
  def change
    add_column :uploads, :sha, :string, null: true
    add_index :uploads, :sha, unique: true
  end
end
