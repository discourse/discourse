# frozen_string_literal: true

class AddSidebarLinkToFilteredListToUserOption < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :sidebar_link_to_filtered_list, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE user_options
      SET sidebar_link_to_filtered_list = true
      WHERE sidebar_list_destination = 1
    SQL
  end
end
