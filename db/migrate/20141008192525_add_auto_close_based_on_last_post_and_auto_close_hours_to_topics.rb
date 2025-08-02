# frozen_string_literal: true

class AddAutoCloseBasedOnLastPostAndAutoCloseHoursToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :auto_close_based_on_last_post, :boolean, default: false
    add_column :topics, :auto_close_hours, :float
  end
end
