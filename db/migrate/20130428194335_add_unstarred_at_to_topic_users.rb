# frozen_string_literal: true

class AddUnstarredAtToTopicUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_users, :unstarred_at, :datetime
  end
end
