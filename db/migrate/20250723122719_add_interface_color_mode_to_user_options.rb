# frozen_string_literal: true

class AddInterfaceColorModeToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :interface_color_mode, :integer, null: false, default: 1
  end
end
