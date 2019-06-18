# frozen_string_literal: true

class AddPostTypeToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :post_type, :integer, default: 1, null: false
  end
end
