# frozen_string_literal: true

class AddHighestWhispererPostNumberToTopics < ActiveRecord::Migration[7.2]
  def up
    add_column :topics, :highest_whisperer_post_number, :integer, default: 0, null: false
    execute "UPDATE topics SET highest_whisperer_post_number = highest_staff_post_number"
  end

  def down
    remove_column :topics, :highest_whisperer_post_number
  end
end
