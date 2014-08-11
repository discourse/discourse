class About
  include ActiveModel::Serialization

  attr_accessor :moderators,
                :admins

  def moderators
    @moderators ||= User.where(moderator: true)
  end

  def admins
    @admins ||= User.where(admin: true)
  end

  def stats
    @stats ||= {
       topic_count: Topic.listable_topics.count,
       post_count: Post.count,
       user_count: User.count,
       topics_7_days: Topic.listable_topics.where('created_at > ?', 7.days.ago).count,
       posts_7_days: Post.where('created_at > ?', 7.days.ago).count,
       users_7_days: User.where('created_at > ?', 7.days.ago).count
    }
  end

end
