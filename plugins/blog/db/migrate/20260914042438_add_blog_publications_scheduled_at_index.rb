# frozen_string_literal: true

class AddBlogPublicationsScheduledAtIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :discourse_blog_publications,
              :scheduled_at,
              where: "scheduled_at IS NOT NULL",
              name: "idx_discourse_blog_publications_scheduled_at"
  end
end
