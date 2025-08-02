# frozen_string_literal: true

class AddExtensionToTopicLinks < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_links, :extension, :string, limit: 10
    add_index :topic_links, :extension
  end
end
