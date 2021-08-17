# frozen_string_literal: true

class AddExternalUploadIdentifierIndexToExternalUploadStubs < ActiveRecord::Migration[6.1]
  def change
    add_index :external_upload_stubs, :external_upload_identifier
  end
end
