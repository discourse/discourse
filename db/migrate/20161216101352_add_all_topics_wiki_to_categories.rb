class AddAllTopicsWikiToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :all_topics_wiki, :boolean, default: false, null: false
  end
end