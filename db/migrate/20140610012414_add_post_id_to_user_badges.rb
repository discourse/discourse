# frozen_string_literal: true

class AddPostIdToUserBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :user_badges, :post_id, :integer
  end
end
