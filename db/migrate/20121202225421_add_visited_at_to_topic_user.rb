# frozen_string_literal: true

class AddVisitedAtToTopicUser < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_users, :last_visited_at, :datetime
    add_column :topic_users, :first_visited_at, :datetime
  end
end
