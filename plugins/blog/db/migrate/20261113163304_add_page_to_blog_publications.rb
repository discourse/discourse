# frozen_string_literal: true
class AddPageToBlogPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_publications, :page, :boolean, null: false, default: false
  end
end
