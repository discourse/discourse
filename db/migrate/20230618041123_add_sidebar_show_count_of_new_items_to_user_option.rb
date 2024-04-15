# frozen_string_literal: true

class AddSidebarShowCountOfNewItemsToUserOption < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options,
               :sidebar_show_count_of_new_items,
               :boolean,
               default: false,
               null: false

    execute <<~SQL
      UPDATE user_options
      SET sidebar_show_count_of_new_items = true
      WHERE sidebar_list_destination = 1
    SQL
  end
end
