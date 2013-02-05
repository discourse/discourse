class AddAnotherFeaturedUserToTopics < ActiveRecord::Migration
  def change
    add_column :topics, :featured_user4_id, :integer, null: true
  end
end
