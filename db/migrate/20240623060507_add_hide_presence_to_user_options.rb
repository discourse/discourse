# frozen_string_literal: true
class AddHidePresenceToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :hide_presence, :boolean, default: false, null: false
  end
end
