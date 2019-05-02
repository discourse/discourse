# frozen_string_literal: true

class AddIncomingLinkCountToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :incoming_link_count, :integer, default: 0, null: false
  end
end
