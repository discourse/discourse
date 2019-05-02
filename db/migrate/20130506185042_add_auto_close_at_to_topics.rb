# frozen_string_literal: true

class AddAutoCloseAtToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :auto_close_at,      :datetime
    add_column :topics, :auto_close_user_id, :integer
  end
end
