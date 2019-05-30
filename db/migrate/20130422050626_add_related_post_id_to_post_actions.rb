# frozen_string_literal: true

class AddRelatedPostIdToPostActions < ActiveRecord::Migration[4.2]
  def change
    add_column :post_actions, :related_post_id, :integer
  end
end
