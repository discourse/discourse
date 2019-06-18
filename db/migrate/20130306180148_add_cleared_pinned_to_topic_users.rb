# frozen_string_literal: true

class AddClearedPinnedToTopicUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_users, :cleared_pinned_at, :datetime, null: true

    add_column :topics, :pinned_at, :datetime, null: true
    execute "UPDATE topics SET pinned_at = created_at WHERE pinned"
    remove_column :topics, :pinned
  end
end
