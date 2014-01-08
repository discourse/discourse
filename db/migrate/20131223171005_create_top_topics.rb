class CreateTopTopics < ActiveRecord::Migration
  def change
    create_table :top_topics, force: true do |t|
      t.belongs_to :topic

      TopTopic.periods.each do |period|
        TopTopic.sort_orders.each do |sort|
          t.integer "#{period}_#{sort}_count".to_sym, null: false, default: 0
        end
      end

    end

    add_index :top_topics, :topic_id, unique: true

    TopTopic.periods.each do |period|
      TopTopic.sort_orders.each do |sort|
        add_index :top_topics, "#{period}_#{sort}_count".to_sym, order: 'desc'
      end
    end

  end
end
