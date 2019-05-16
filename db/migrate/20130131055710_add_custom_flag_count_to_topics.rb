# frozen_string_literal: true

class AddCustomFlagCountToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :custom_flag_count, :integer, null: false, default: 0
    add_column :posts, :custom_flag_count, :integer, null: false, default: 0
  end
end
