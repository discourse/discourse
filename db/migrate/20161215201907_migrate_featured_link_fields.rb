class MigrateFeaturedLinkFields < ActiveRecord::Migration
  def change
    add_column :topics, :featured_link, :string
    add_column :categories, :topic_featured_link_allowed, :boolean, default: true
  end
end
