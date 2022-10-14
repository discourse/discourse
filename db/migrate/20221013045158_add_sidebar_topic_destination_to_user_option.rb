# frozen_string_literal: true

class AddSidebarTopicDestinationToUserOption < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :sidebar_topic_destination, :integer, default: false
  end
end
