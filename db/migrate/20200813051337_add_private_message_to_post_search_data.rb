# frozen_string_literal: true

class AddPrivateMessageToPostSearchData < ActiveRecord::Migration[6.0]
  def up
    add_column :post_search_data, :private_message, :boolean
  end

  def down
    remove_column :post_search_data, :private_message
  end
end
