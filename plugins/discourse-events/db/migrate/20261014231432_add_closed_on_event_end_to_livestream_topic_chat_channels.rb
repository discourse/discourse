# frozen_string_literal: true

class AddClosedOnEventEndToLivestreamTopicChatChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :livestream_topic_chat_channels,
               :closed_on_event_end,
               :boolean,
               default: false,
               null: false
  end
end
