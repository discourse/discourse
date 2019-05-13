# frozen_string_literal: true

class AddMissingUploadsIgnoredIndexToPostCustomFields < ActiveRecord::Migration[5.2]
  def change
    add_index :post_custom_fields, :post_id, unique: true, where: "name = 'missing uploads ignored'", name: "index_post_id_where_missing_uploads_ignored"
  end
end
