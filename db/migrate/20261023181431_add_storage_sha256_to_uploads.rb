# frozen_string_literal: true

class AddStorageSha256ToUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :uploads, :storage_sha256, :string
  end
end
