class AddResolutionColumnToTopics < ActiveRecord::Migration[6.0]
  def change
    add_column :topics, :resolution, :boolean, default: false, null: false
  end
end
