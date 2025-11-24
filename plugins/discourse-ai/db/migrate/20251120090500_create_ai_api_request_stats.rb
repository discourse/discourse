# frozen_string_literal: true

class CreateAiApiRequestStats < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_api_request_stats do |t|
      t.datetime :bucket_date, null: false
      t.bigint :user_id
      t.integer :provider_id, null: false
      t.bigint :llm_id
      t.string :language_model, limit: 255
      t.string :feature_name, limit: 255
      t.integer :request_tokens, default: 0, null: false
      t.integer :response_tokens, default: 0, null: false
      t.integer :cache_read_tokens, default: 0, null: false
      t.integer :cache_write_tokens, default: 0, null: false
      t.integer :usage_count, default: 1, null: false
      t.boolean :rolled_up, default: false, null: false
      t.timestamps
    end

    add_index :ai_api_request_stats, %i[bucket_date feature_name]
    add_index :ai_api_request_stats, %i[bucket_date language_model]
    add_index :ai_api_request_stats, %i[bucket_date user_id]
    add_index :ai_api_request_stats, %i[bucket_date llm_id]
    add_index :ai_api_request_stats, %i[created_at feature_name]
    add_index :ai_api_request_stats, %i[created_at language_model]
    add_index :ai_api_request_stats, %i[created_at user_id]
    add_index :ai_api_request_stats, %i[bucket_date rolled_up], where: "rolled_up = false"
  end
end
