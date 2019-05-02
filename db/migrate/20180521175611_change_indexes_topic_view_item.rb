# frozen_string_literal: true

class ChangeIndexesTopicViewItem < ActiveRecord::Migration[5.1]
  def up
    remove_index :topic_views,
      column: [:ip_address, :topic_id],
      name: :ip_address_topic_id_topic_views,
      unique: true

    remove_index :topic_views,
      column: [:user_id, :topic_id],
      name: :user_id_topic_id_topic_views,
      unique: true
  end

  def down
  end
end
