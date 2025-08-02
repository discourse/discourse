# frozen_string_literal: true

class AddTopicsUnreadWhenClosedToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :topics_unread_when_closed, :boolean, default: true, null: false
  end
end
