# frozen_string_literal: true

class CreateAiPostImageCaptions < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_post_image_captions do |t|
      t.integer :post_id, null: false
      t.integer :upload_id, null: false
      t.string :base62_sha1, null: false, limit: 27
      t.string :locale, null: false, limit: 20
      t.text :description
      t.integer :attempts, null: false, default: 0
      t.datetime :last_attempted_at
      t.text :last_error
      t.timestamps null: false
    end

    add_index :ai_post_image_captions,
              %i[post_id locale base62_sha1],
              unique: true,
              name: "idx_ai_post_image_captions_lookup"
    add_index :ai_post_image_captions,
              %i[base62_sha1 locale],
              name: "idx_ai_post_image_captions_reuse"
  end
end
