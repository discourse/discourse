# frozen_string_literal: true

class AddAllowUnknownSenderTopicRepliesToGroup < ActiveRecord::Migration[6.0]
  def up
    add_column :groups, :allow_unknown_sender_topic_replies, :boolean, default: false, null: false
  end

  def down
    remove_column :groups, :allow_unknown_sender_topic_replies
  end
end
