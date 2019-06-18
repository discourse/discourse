# frozen_string_literal: true

class AddBioCookedVersionToUserProfile < ActiveRecord::Migration[4.2]
  def change
    add_column :user_profiles, :bio_cooked_version, :integer
    add_index :user_profiles, [:bio_cooked_version]
  end
end
