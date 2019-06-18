# frozen_string_literal: true

class AddScoresToTopTopics < ActiveRecord::Migration[4.2]
  def change
    [:daily, :weekly, :monthly, :yearly].each do |period|
      add_column :top_topics, "#{period}_score".to_sym, :float
    end
  end
end
