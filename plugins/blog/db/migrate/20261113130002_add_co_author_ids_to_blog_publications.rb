# frozen_string_literal: true
class AddCoAuthorIdsToBlogPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_publications, :co_author_ids, :integer, array: true, null: false, default: []
  end
end
