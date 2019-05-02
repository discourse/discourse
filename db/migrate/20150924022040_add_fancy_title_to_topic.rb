# frozen_string_literal: true

class AddFancyTitleToTopic < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :fancy_title, :string, limit: 400, null: true
  end
end
