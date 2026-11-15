# frozen_string_literal: true
class AddRevokedByPublishToBlogReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_reviews, :revoked_by_publish, :boolean, default: false, null: false
  end
end
