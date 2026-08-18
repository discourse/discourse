# frozen_string_literal: true
class AddLivestreamTablesToCalendar < ActiveRecord::Migration[8.0]
  # NOTE: This migration is a no-op for sites that had previously
  # installed the discourse-livestream plugin.
  def up
    if !table_exists?(:livestream_topic_chat_channels)
      create_table :livestream_topic_chat_channels do |t|
        t.bigint :topic_id, null: false
        t.bigint :chat_channel_id, null: false
        t.timestamps
      end

      add_index :livestream_topic_chat_channels,
                %i[topic_id chat_channel_id],
                unique: true,
                name: "unique_livestream_topic_chat_channels"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
