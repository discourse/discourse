class AddTitleToTopicLinks < ActiveRecord::Migration
  def change
    add_column :topic_links, :title, :string
    add_column :topic_links, :crawled_at, :datetime
  end
end
