class About
  include ActiveModel::Serialization
  include StatsCacheable

  attr_accessor :moderators,
                :admins

  def self.stats_cache_key
    'about-stats'
  end

  def self.fetch_stats
    About.new.stats
  end

  def version
    Discourse::VERSION::STRING
  end

  def https
    SiteSetting.use_https
  end

  def title
    SiteSetting.title
  end

  def locale
    SiteSetting.default_locale
  end

  def description
    SiteSetting.site_description
  end

  def moderators
    @moderators ||= User.where(moderator: true, admin: false)
                        .where.not(id: Discourse::SYSTEM_USER_ID)
                        .order(:username_lower)
  end

  def admins
    @admins ||= User.where(admin: true)
                    .where.not(id: Discourse::SYSTEM_USER_ID)
                    .order(:username_lower)
  end

  def stats
    @stats ||= {
       topic_count: Topic.listable_topics.count,
       post_count: Post.count,
       user_count: User.real.count,
       topics_7_days: Topic.listable_topics.where('created_at > ?', 7.days.ago).count,
       topics_30_days: Topic.listable_topics.where('created_at > ?', 30.days.ago).count,
       posts_7_days: Post.where('created_at > ?', 7.days.ago).count,
       posts_30_days: Post.where('created_at > ?', 30.days.ago).count,
       users_7_days: User.where('created_at > ?', 7.days.ago).count,
       users_30_days: User.where('created_at > ?', 30.days.ago).count,
       active_users_7_days: User.where('last_seen_at > ?', 7.days.ago).count,
       active_users_30_days: User.where('last_seen_at > ?', 30.days.ago).count,
       like_count: UserAction.where(action_type: UserAction::LIKE).count,
       likes_7_days: UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 7.days.ago).count,
       likes_30_days: UserAction.where(action_type: UserAction::LIKE).where("created_at > ?", 30.days.ago).count
    }
  end

end
