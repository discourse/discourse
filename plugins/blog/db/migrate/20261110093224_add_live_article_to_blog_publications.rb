# frozen_string_literal: true
class AddLiveArticleToBlogPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_publications, :cooked, :text
    add_column :blog_publications, :image_url, :text
  end
end
