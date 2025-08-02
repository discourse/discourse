# frozen_string_literal: true

class AddVerifiedColumnToUploads < ActiveRecord::Migration[6.0]
  def change
    add_column :uploads, :verified, :boolean, null: true
  end
end
