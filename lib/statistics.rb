# frozen_string_literal: true

class Statistics
  def self.active_users
    {
      last_day: User.where("last_seen_at > ?", 1.day.ago).count,
      "7_days": User.where("last_seen_at > ?", 7.days.ago).count,
      "30_days": User.where("last_seen_at > ?", 30.days.ago).count,
    }
  end

  def self.likes
    {
      last_day:
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 1.day.ago).count,
      "7_days":
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 7.days.ago).count,
      "30_days":
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 30.days.ago).count,
      count: UserAction.where(action_type: UserAction::LIKE).count,
    }
  end

  def self.posts
    {
      last_day: Post.where("created_at > ?", 1.day.ago).count,
      "7_days": Post.where("created_at > ?", 7.days.ago).count,
      "30_days": Post.where("created_at > ?", 30.days.ago).count,
      count: Post.count,
    }
  end

  def self.topics
    {
      last_day: Topic.listable_topics.where("created_at > ?", 1.day.ago).count,
      "7_days": Topic.listable_topics.where("created_at > ?", 7.days.ago).count,
      "30_days": Topic.listable_topics.where("created_at > ?", 30.days.ago).count,
      count: Topic.listable_topics.count,
    }
  end

  def self.users
    {
      last_day: User.real.where("created_at > ?", 1.day.ago).count,
      "7_days": User.real.where("created_at > ?", 7.days.ago).count,
      "30_days": User.real.where("created_at > ?", 30.days.ago).count,
      count: User.real.count,
    }
  end

  def self.participating_users
    {
      last_day: participating_users_count(1.day.ago),
      "7_days": participating_users_count(7.days.ago),
      "30_days": participating_users_count(30.days.ago),
    }
  end

  private

  def self.participating_users_count(date)
    subqueries = [
      "SELECT DISTINCT user_id FROM user_actions WHERE created_at > :date AND action_type IN (:action_types)",
    ]

    if ActiveRecord::Base.connection.data_source_exists?("chat_messages")
      subqueries << "SELECT DISTINCT user_id FROM chat_messages WHERE created_at > :date"
    end

    if ActiveRecord::Base.connection.data_source_exists?("chat_message_reactions")
      subqueries << "SELECT DISTINCT user_id FROM chat_message_reactions WHERE created_at > :date"
    end

    sql = "SELECT COUNT(user_id) FROM (#{subqueries.join(" UNION ")}) u"

    DB.query_single(sql, date: date, action_types: UserAction::USER_ACTED_TYPES).first
  end
end
