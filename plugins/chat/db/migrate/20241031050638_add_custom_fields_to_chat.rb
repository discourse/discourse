# frozen_string_literal: true

class AddCustomFieldsToChat < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_thread_custom_fields do |t|
      t.bigint :thread_id, null: false, index: true
      t.string :name, limit: 256, null: false
      t.string :value, limit: 1_000_000
      t.timestamps null: false
    end

    create_table :chat_message_custom_fields do |t|
      t.bigint :message_id, null: false, index: true
      t.string :name, limit: 256, null: false
      t.string :value, limit: 1_000_000
      t.timestamps null: false
    end

    create_table :chat_channel_custom_fields do |t|
      t.bigint :channel_id, null: false, index: true
      t.string :name, limit: 256, null: false
      t.string :value, limit: 1_000_000
      t.timestamps null: false
    end

    add_index :chat_thread_custom_fields, %i[thread_id name], unique: true
    add_index :chat_message_custom_fields, %i[message_id name], unique: true
    add_index :chat_channel_custom_fields, %i[channel_id name], unique: true
  end
end
