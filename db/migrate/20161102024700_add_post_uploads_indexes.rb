# frozen_string_literal: true

class AddPostUploadsIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :post_uploads, :post_id
    add_index :post_uploads, :upload_id
  end
end
