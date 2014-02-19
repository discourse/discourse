class CreateTopTopics < ActiveRecord::Migration
  PERIODS = [:yearly, :monthly, :weekly, :daily]
  SORT_ORDERS = [:posts, :views, :likes]

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
        add_index :top_topics, "#{period}_#{sort}_count".to_sym, order: 'desc'
      end
    end

  end
end
