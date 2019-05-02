# frozen_string_literal: true

class AddCategoryIdToTopicStatusUpdates < ActiveRecord::Migration[4.2]
  def change
    add_column :topic_status_updates, :category_id, :integer
  end
end
