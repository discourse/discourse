# frozen_string_literal: true

class AddAllTopicsWikiToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :all_topics_wiki, :boolean, default: false, null: false
  end
end
