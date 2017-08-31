class AddFeaturedTopicsToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :num_featured_topics, :integer, default: 3

    result = execute("select value from site_settings where name = 'category_featured_topics' and value != '3'")
    if result.count > 0 && result[0]["value"].to_i > 0
      execute "UPDATE categories SET num_featured_topics = #{result[0]["value"].to_i}"
    end
  end

  def down
    remove_column :categories, :num_featured_topics
  end
end
