# frozen_string_literal: true

class AddSidebarListDestinationToUserOption < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :sidebar_list_destination, :integer, default: 0, null: false
  end
end
