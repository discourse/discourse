# frozen_string_literal: true

module DiscourseBoosts
  module PostExtension
    def self.prepended(base)
      base.has_many :boosts,
                    -> { order(:created_at) },
                    class_name: "DiscourseBoosts::Boost",
                    dependent: :delete_all,
                    inverse_of: :post

      base.before_destroy :delete_boost_notifications
    end

    private

    def delete_boost_notifications
      Notification.where(
        user_id: user_id,
        topic_id: topic_id,
        post_number: post_number,
        notification_type: Notification.types[:boost],
      ).delete_all
    end
  end
end
