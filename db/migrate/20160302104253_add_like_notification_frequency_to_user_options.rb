class AddLikeNotificationFrequencyToUserOptions < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :like_notification_frequency, :integer, null: false, default: 1
  end
end
