class ScheduleEmojiGrant < ActiveRecord::Migration
  def up
    Jobs.enqueue(:grant_emoji)
  end
end
