# frozen_string_literal: true

class AddNotifyOnLinkedPostsToUserOptions < ActiveRecord::Migration[7.1]
  def change
    add_column :user_options, :notify_on_linked_posts, :boolean, default: true, null: false
  end
end
