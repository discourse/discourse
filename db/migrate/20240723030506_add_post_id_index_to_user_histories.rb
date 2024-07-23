# frozen_string_literal: true
class AddPostIdIndexToUserHistories < ActiveRecord::Migration[7.1]
  def change
    add_index :user_histories, :post_id
  end
end
