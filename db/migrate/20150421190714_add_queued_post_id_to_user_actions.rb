# frozen_string_literal: true

class AddQueuedPostIdToUserActions < ActiveRecord::Migration[4.2]
  def change
    add_column :user_actions, :queued_post_id, :integer, null: true
  end
end
