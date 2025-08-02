# frozen_string_literal: true

class AddFeaturedTopicIdToUserProfiles < ActiveRecord::Migration[6.0]
  def change
    add_column :user_profiles, :featured_topic_id, :integer
  end
end
