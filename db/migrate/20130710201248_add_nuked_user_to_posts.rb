# frozen_string_literal: true

class AddNukedUserToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :nuked_user, :boolean, default: false
  end
end
