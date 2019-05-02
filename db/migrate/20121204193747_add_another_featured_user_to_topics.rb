# frozen_string_literal: true

class AddAnotherFeaturedUserToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :featured_user4_id, :integer, null: true
  end
end
