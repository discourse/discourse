# frozen_string_literal: true

class AddInterfaceColorModeToUserOption < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :interface_color_mode, :integer, default: 1, null: false
  end
end
