# frozen_string_literal: true

class AddTopicTitlePlaceholderToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :topic_title_placeholder, :string, null: true
  end
end
