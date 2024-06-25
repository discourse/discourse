# frozen_string_literal: true
class AddHideProfileToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :hide_profile, :boolean, default: false, null: false
  end
end
