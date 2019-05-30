# frozen_string_literal: true

class CreatePostDetails < ActiveRecord::Migration[4.2]
  def change
    create_table :post_details do |t|
      t.belongs_to :post
      t.string     :key
      t.string     :value, size: 512
      t.text       :extra

      t.timestamps null: false
    end

    add_index :post_details, [:post_id, :key], unique: true
  end
end
