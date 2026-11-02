# frozen_string_literal: true

class CreateDiscourseBlogReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_blog_reviews do |table|
      table.bigint :topic_id, null: false
      table.bigint :creator_id, null: false
      table.string :token_digest, null: false, limit: 64
      table.string :label, null: false, default: "", limit: 100
      table.string :title, null: false
      table.text :cooked, null: false
      table.integer :post_version, null: false
      table.datetime :expires_at, null: false
      table.datetime :revoked_at
      table.timestamps
    end
    add_index :discourse_blog_reviews, :token_digest, unique: true
    add_index :discourse_blog_reviews, %i[topic_id created_at]

    create_table :discourse_blog_review_feedback do |table|
      table.bigint :review_id, null: false
      table.string :name, null: false, default: "", limit: 100
      table.string :email, null: false, default: "", limit: 254
      table.text :message, null: false
      table.timestamps
    end
    add_index :discourse_blog_review_feedback,
              %i[review_id created_at],
              name: "idx_blog_review_feedback_review_created"
  end
end
