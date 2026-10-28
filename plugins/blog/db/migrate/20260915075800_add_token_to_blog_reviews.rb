# frozen_string_literal: true

class AddTokenToBlogReviews < ActiveRecord::Migration[8.0]
  def up
    add_column :discourse_blog_reviews, :token, :string, limit: 64
    add_index :discourse_blog_reviews, :token, unique: true

    # Existing rows stored only a digest, so their links can no longer be resolved.
    execute <<~SQL
      UPDATE discourse_blog_reviews
         SET revoked_at = NOW(), updated_at = NOW()
       WHERE token IS NULL
         AND revoked_at IS NULL
    SQL

    change_column_null :discourse_blog_reviews, :token_digest, true
  end

  def down
    change_column_null :discourse_blog_reviews, :token_digest, false
    remove_index :discourse_blog_reviews, :token
    remove_column :discourse_blog_reviews, :token
  end
end
