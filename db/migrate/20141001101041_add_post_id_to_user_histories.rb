# frozen_string_literal: true

class AddPostIdToUserHistories < ActiveRecord::Migration[4.2]
  def change
    add_column :user_histories, :post_id, :integer
  end
end
