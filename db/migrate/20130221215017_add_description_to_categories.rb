# frozen_string_literal: true

class AddDescriptionToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :description, :text, null: true

    # While we're at it, remove unused columns
    remove_column :categories, :top1_topic_id
    remove_column :categories, :top2_topic_id
    remove_column :categories, :top1_user_id
    remove_column :categories, :top2_user_id

    # some ancient installs may have bad category descriptions
    # attempt to fix
    if !DB.query_single("SELECT 1 FROM categories limit 1").empty?

      # Reaching into post revisor is not ideal here, but this code
      # should almost never run, so bypass it
      Discourse.reset_active_record_cache

      Category.order('id').each do |c|
        post = c.topic.ordered_posts.first
        PostRevisor.new(post).update_category_description
      end

      Discourse.reset_active_record_cache
    end

  end

  def down
    remove_column :categories, :description
  end

end
