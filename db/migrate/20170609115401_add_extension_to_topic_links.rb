class AddExtensionToTopicLinks < ActiveRecord::Migration
  def change
    add_column :topic_links, :extension, :string, limit: 5
    add_index :topic_links, :extension
  end
end
