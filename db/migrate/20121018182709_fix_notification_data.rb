# frozen_string_literal: true

class FixNotificationData < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE notifications SET data = replace(data, 'thread_title', 'topic_title')"
  end

  def down
  end
end
