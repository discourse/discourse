class AddFromQuoteToTopicLink < ActiveRecord::Migration
  def change
    add_column :topic_links, :from_quote, :boolean, default: false, null: false
  end
end
