class AddIndexToUploads < ActiveRecord::Migration
  def change
    add_index :uploads, [:id, :url]
  end
end
