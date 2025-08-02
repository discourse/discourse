# frozen_string_literal: true

class AddLastEmailedPostNumberToTopicUser < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_users, :last_emailed_post_number, :integer
  end
end
