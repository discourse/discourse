# frozen_string_literal: true

class AddAccessControlColumnsToUpload < ActiveRecord::Migration[6.0]
  def up
    add_reference :uploads, :access_control_post, foreign_key: { to_table: :posts }, index: true, null: true
    add_column :uploads, :original_sha1, :string, null: true
    add_index :uploads, :original_sha1
  end

  def down
    remove_column :uploads, :access_control_post_id
    remove_column :uploads, :original_sha1
  end
end
