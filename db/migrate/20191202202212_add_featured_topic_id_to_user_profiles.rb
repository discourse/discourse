# frozen_string_literal: true

class AddFeaturedTopicIdToUserProfiles < ActiveRecord::Migration[6.0]
  def change
    add_reference :user_profiles, :featured_topic, foreign_key: { to_table: 'topics' }
  end
end
