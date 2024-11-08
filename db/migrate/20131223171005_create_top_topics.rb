# frozen_string_literal: true

class CreateTopTopics < ActiveRecord::Migration[4.2]
  PERIODS = %i[yearly monthly weekly daily].freeze
  SORT_ORDERS = %i[posts views likes].freeze

  def change
    create_table :top_topics, force: true do |t|
      t.belongs_to :topic

      PERIODS.each do |period|
        SORT_ORDERS.each do |sort|
          t.integer "#{period}_#{sort}_count".to_sym, null: false, default: 0
        end
      end
    end

    add_index :top_topics, :topic_id, unique: true

    PERIODS.each do |period|
      SORT_ORDERS.each do |sort|
        add_index :top_topics, "#{period}_#{sort}_count".to_sym, order: "desc"
      end
    end
  end
end
