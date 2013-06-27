class AddUrlIndexToUploads < ActiveRecord::Migration
  def change
    add_index :uploads, :url
  end
end
