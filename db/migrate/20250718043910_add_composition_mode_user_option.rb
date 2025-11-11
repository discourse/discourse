# frozen_string_literal: true
class AddCompositionModeUserOption < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :composition_mode, :integer, default: 1, null: false
  end
end
