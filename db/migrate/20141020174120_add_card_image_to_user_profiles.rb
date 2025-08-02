# frozen_string_literal: true

class AddCardImageToUserProfiles < ActiveRecord::Migration[4.2]
  def change
    add_column :user_profiles, :card_image_badge_id, :integer
  end
end
