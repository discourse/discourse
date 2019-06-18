# frozen_string_literal: true

class AddMutedAtToTopicUser < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_users, :muted_at, :datetime
    change_column :topic_users, :last_read_post_number, :integer, null: true
    change_column_default :topic_users, :last_read_post_number, nil
  end
end
