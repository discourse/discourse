# frozen_string_literal: true

class RemoveLimitForFancyTitleInTopics < ActiveRecord::Migration[6.1]
  def change
    change_column :topics, :fancy_title, :string, limit: nil
  end
end
