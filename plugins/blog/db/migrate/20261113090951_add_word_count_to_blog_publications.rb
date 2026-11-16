# frozen_string_literal: true
class AddWordCountToBlogPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_publications, :word_count, :integer
  end
end
