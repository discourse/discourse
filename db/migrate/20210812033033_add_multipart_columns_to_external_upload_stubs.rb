# frozen_string_literal: true

class AddMultipartColumnsToExternalUploadStubs < ActiveRecord::Migration[6.1]
  def change
    add_column :external_upload_stubs, :multipart, :boolean, default: false, null: false
    add_column :external_upload_stubs, :external_upload_identifier, :string, null: true, index: true
  end
end
