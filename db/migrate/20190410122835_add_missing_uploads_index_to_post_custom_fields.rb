# frozen_string_literal: true

class AddMissingUploadsIndexToPostCustomFields < ActiveRecord::Migration[5.2]
  def change
    add_index :post_custom_fields, :post_id, unique: true, where: "name = 'missing uploads'"
  end
end
