# frozen_string_literal: true
class AddPublishedToBlogInstances < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_instances, :published, :boolean, null: false, default: true
  end
end
