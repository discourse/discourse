class AddSlugToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :slug, :string
  end
end
