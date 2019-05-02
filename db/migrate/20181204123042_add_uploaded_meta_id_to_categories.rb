# frozen_string_literal: true

class AddUploadedMetaIdToCategories < ActiveRecord::Migration[5.2]
  def change
    add_column :categories, :uploaded_meta_id, :integer
  end
end
