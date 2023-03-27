# frozen_string_literal: true

module Chat
  class Statistics
    def self.about_messages
      {
        :last_day => Chat::Message.where("created_at > ?", 1.days.ago).count,
        "7_days" => Chat::Message.where("created_at > ?", 7.days.ago).count,
        "30_days" => Chat::Message.where("created_at > ?", 30.days.ago).count,
        :previous_30_days =>
          Chat::Message.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
        :count => Chat::Message.count,
      }
    end

    def self.about_channels
      {
        :last_day => Chat::Channel.where(status: :open).where("created_at > ?", 1.days.ago).count,
        "7_days" => Chat::Channel.where(status: :open).where("created_at > ?", 7.days.ago).count,
        "30_days" => Chat::Channel.where(status: :open).where("created_at > ?", 30.days.ago).count,
        :previous_30_days =>
          Chat::Channel
            .where(status: :open)
            .where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago)
            .count,
        :count => Chat::Channel.where(status: :open).count,
      }
    end

    def self.about_users
      {
        :last_day => Chat::Message.where("created_at > ?", 1.days.ago).distinct.count(:user_id),
        "7_days" => Chat::Message.where("created_at > ?", 7.days.ago).distinct.count(:user_id),
        "30_days" => Chat::Message.where("created_at > ?", 30.days.ago).distinct.count(:user_id),
        :previous_30_days =>
          Chat::Message
            .where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago)
            .distinct
            .count(:user_id),
        :count => Chat::Message.distinct.count(:user_id),
      }
    end

    def self.monthly
      start_of_month = Time.zone.now.beginning_of_month
      {
        messages: Chat::Message.where("created_at > ?", start_of_month).count,
        channels: Chat::Channel.where(status: :open).where("created_at > ?", start_of_month).count,
        users: Chat::Message.where("created_at > ?", start_of_month).distinct.count(:user_id),
      }
    end
  end
end
