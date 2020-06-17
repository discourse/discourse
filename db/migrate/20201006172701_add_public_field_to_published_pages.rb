# frozen_string_literal: true

class AddPublicFieldToPublishedPages < ActiveRecord::Migration[6.0]
  def change
    add_column :published_pages, :public, :boolean, null: false, default: false
  end
end
