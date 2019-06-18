# frozen_string_literal: true

class CreatePostUploadJoinTable < ActiveRecord::Migration[4.2]
  def change
    create_table :posts_uploads, force: true, id: false do |t|
      t.integer :post_id
      t.integer :upload_id
    end

    add_index :posts_uploads, :post_id
    add_index :posts_uploads, :upload_id
    add_index :posts_uploads, [:post_id, :upload_id], unique: true
  end
end
