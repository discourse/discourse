# frozen_string_literal: true

class CreateTopTopics < ActiveRecord::Migration[4.2]
  PERIODS = %i[yearly monthly weekly daily]
  SORT_ORDERS = %i[posts views likes]

  def change
    create_table :top_topics, force: true do |t|
      t.belongs_to :topic

      PERIODS.each do |period|
        SORT_ORDERS.each { |sort| t.integer :"#{period}_#{sort}_count", null: false, default: 0 }
      end
    end

    add_index :top_topics, :topic_id, unique: true

    PERIODS.each do |period|
      SORT_ORDERS.each { |sort| add_index :top_topics, :"#{period}_#{sort}_count", order: "desc" }
    end
  end
end
