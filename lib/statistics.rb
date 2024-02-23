# frozen_string_literal: true

class Statistics
  def self.active_users
    {
      last_day: User.where("last_seen_at > ?", 1.days.ago).count,
      "7_days": User.where("last_seen_at > ?", 7.days.ago).count,
      "30_days": User.where("last_seen_at > ?", 30.days.ago).count,
    }
  end

  def self.likes
    {
      last_day:
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 1.days.ago).count,
      "7_days":
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 7.days.ago).count,
      "30_days":
        UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 30.days.ago).count,
      count: UserAction.where(action_type: UserAction::LIKE).count,
    }
  end

  def self.posts
    {
      last_day: Post.where("created_at > ?", 1.days.ago).count,
      "7_days": Post.where("created_at > ?", 7.days.ago).count,
      "30_days": Post.where("created_at > ?", 30.days.ago).count,
      count: Post.count,
    }
  end

  def self.topics
    {
      last_day: Topic.listable_topics.where("created_at > ?", 1.days.ago).count,
      "7_days": Topic.listable_topics.where("created_at > ?", 7.days.ago).count,
      "30_days": Topic.listable_topics.where("created_at > ?", 30.days.ago).count,
      count: Topic.listable_topics.count,
    }
  end

  def self.users
    {
      last_day: User.real.where("created_at > ?", 1.days.ago).count,
      "7_days": User.real.where("created_at > ?", 7.days.ago).count,
      "30_days": User.real.where("created_at > ?", 30.days.ago).count,
      count: User.real.count,
    }
  end

  def self.discourse_discover
    { enrolled: SiteSetting.include_in_discourse_discover? }
  end
end
