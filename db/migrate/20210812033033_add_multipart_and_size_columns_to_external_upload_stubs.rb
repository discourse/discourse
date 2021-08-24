# frozen_string_literal: true

class AddMultipartAndSizeColumnsToExternalUploadStubs < ActiveRecord::Migration[6.1]
  def up
    add_column :external_upload_stubs, :multipart, :boolean, default: false, null: false
    add_column :external_upload_stubs, :external_upload_identifier, :string, null: true
    add_column :external_upload_stubs, :filesize, :bigint

    add_index :external_upload_stubs, :external_upload_identifier

    # this feature is not actively used yet so this will be safe, also the rows in this
    # table are regularly deleted
    DB.exec("UPDATE external_upload_stubs SET filesize = 0 WHERE filesize IS NULL")

    change_column_null :external_upload_stubs, :filesize, false
  end

  def down
    remove_column :external_upload_stubs, :multipart
    remove_column :external_upload_stubs, :external_upload_identifier
    remove_column :external_upload_stubs, :filesize
  end
end
