# frozen_string_literal: true

class AddLastPostedAtToTopicUser < ActiveRecord::Migration[6.0]
  def change
    add_column :topic_users, :last_posted_at, :datetime
  end
end
