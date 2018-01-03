class AddIndexToUploads < ActiveRecord::Migration[4.2]
  def change
    add_index :uploads, [:id, :url]
  end
end
