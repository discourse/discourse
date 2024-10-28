# frozen_string_literal: true

class AddSmartListUserPreference < ActiveRecord::Migration[7.1]
  def change
    add_column :user_options, :enable_smart_lists, :boolean, default: true, null: false
  end
end
