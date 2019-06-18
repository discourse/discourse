# frozen_string_literal: true

class AddReplyBelowToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :reply_below_post_number, :integer, null: true
  end
end
