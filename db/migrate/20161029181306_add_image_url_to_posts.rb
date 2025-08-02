# frozen_string_literal: true

class AddImageUrlToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :image_url, :string
  end
end
