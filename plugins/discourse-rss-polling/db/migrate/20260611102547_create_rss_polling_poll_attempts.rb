# frozen_string_literal: true

class CreateRssPollingPollAttempts < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_rss_polling_poll_attempts do |t|
      t.bigint :rss_feed_id, null: false
      t.integer :status, null: false, default: 0
      t.integer :imported_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.text :error
      t.jsonb :items, null: false, default: []
      t.timestamps null: false
    end

    add_index :discourse_rss_polling_poll_attempts,
              %i[rss_feed_id created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              name: "idx_rss_polling_poll_attempts_on_feed_created_id_desc"
  end
end
