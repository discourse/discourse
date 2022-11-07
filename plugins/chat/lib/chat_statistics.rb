# frozen_string_literal: true

class Chat::Statistics
  def self.about_messages
    {
      :last_day => ChatMessage.where("created_at > ?", 1.days.ago).count,
      "7_days" => ChatMessage.where("created_at > ?", 7.days.ago).count,
      "30_days" => ChatMessage.where("created_at > ?", 30.days.ago).count,
      :previous_30_days =>
        ChatMessage.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
      :count => ChatMessage.count,
    }
  end

  def self.about_channels
    {
      :last_day => ChatChannel.where(status: :open).where("created_at > ?", 1.days.ago).count,
      "7_days" => ChatChannel.where(status: :open).where("created_at > ?", 7.days.ago).count,
      "30_days" => ChatChannel.where(status: :open).where("created_at > ?", 30.days.ago).count,
      :previous_30_days =>
        ChatChannel
          .where(status: :open)
          .where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago)
          .count,
      :count => ChatChannel.where(status: :open).count,
    }
  end

  def self.about_users
    {
      :last_day => ChatMessage.where("created_at > ?", 1.days.ago).distinct.count(:user_id),
      "7_days" => ChatMessage.where("created_at > ?", 7.days.ago).distinct.count(:user_id),
      "30_days" => ChatMessage.where("created_at > ?", 30.days.ago).distinct.count(:user_id),
      :previous_30_days =>
        ChatMessage
          .where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago)
          .distinct
          .count(:user_id),
      :count => ChatMessage.distinct.count(:user_id),
    }
  end

  def self.monthly
    start_of_month = Time.zone.now.beginning_of_month
    {
      messages: ChatMessage.where("created_at > ?", start_of_month).count,
      channels: ChatChannel.where(status: :open).where("created_at > ?", start_of_month).count,
      users: ChatMessage.where("created_at > ?", start_of_month).distinct.count(:user_id),
    }
  end
end
