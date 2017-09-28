class AddUrlIndexToUploads < ActiveRecord::Migration[4.2]
  def change
    add_index :uploads, :url
  end
end
