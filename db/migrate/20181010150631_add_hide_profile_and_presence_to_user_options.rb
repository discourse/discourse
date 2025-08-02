# frozen_string_literal: true

class AddHideProfileAndPresenceToUserOptions < ActiveRecord::Migration[5.2]
  def change
    add_column :user_options, :hide_profile_and_presence, :boolean, default: false, null: false
  end
end
