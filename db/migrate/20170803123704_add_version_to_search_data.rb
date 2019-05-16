# frozen_string_literal: true

class AddVersionToSearchData < ActiveRecord::Migration[4.2]
  def change
    add_column :post_search_data, :version, :integer, default: 0
    add_column :topic_search_data, :version, :integer, default: 0
    add_column :category_search_data, :version, :integer, default: 0
    add_column :user_search_data, :version, :integer, default: 0
  end
end
