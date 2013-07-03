#
# Check whether a user is ready for a new trust level.
#
class Promotion

  def initialize(user)
    @user = user
    setup_regular_requires_hash
  end

  # Review a user for a promotion. Delegates work to a review_#{trust_level} method.
  # Returns true if the user was promoted, false otherwise.
  def review
    # nil users are never promoted
    return false if @user.blank?

    trust_key = TrustLevel.levels[@user.trust_level]

    review_method = :"review_#{trust_key.to_s}"
    return send(review_method) if respond_to?(review_method)

    false
  end

  def review_newuser
    return false if @user.topics_entered < SiteSetting.basic_requires_topics_entered
    return false if @user.posts_read_count < SiteSetting.basic_requires_read_posts
    return false if (@user.time_read / 60) < SiteSetting.basic_requires_time_spent_mins

    @user.change_trust_level!(:basic)

    true
  end

  def review_basic

    return false if @user.topics_entered < @regular_requires[:topics_entered]
    return false if @user.posts_read_count < @regular_requires[:posts_read_count]
    return false if (@user.time_read / 60) < @regular_requires[:time_read]
    return false if @user.days_visited < @regular_requires[:days_visited]
    return false if @user.likes_received < @regular_requires[:likes_received]
    return false if @user.likes_given < @regular_requires[:likes_given]
    return false if @user.topic_reply_count < @regular_requires[:topic_reply_count]

    @user.change_trust_level!(:regular)
  end

  protected

  def setup_regular_requires_hash
    @regular_requires =   { topics_entered: SiteSetting.regular_requires_topics_entered,
                            posts_read_count: SiteSetting.regular_requires_read_posts,
                            time_read: SiteSetting.regular_requires_time_spent_mins,
                            days_visited: SiteSetting.regular_requires_days_visited,
                            likes_received: SiteSetting.regular_requires_likes_received,
                            likes_given: SiteSetting.regular_requires_likes_given,
                            topic_reply_count: SiteSetting.regular_requires_topic_reply_count
                          }
    if @user && @user.trust_level_set_by_admin
      @regular_requires[:topics_entered] -= SiteSetting.basic_requires_topics_entered
      @regular_requires[:posts_read_count] -= SiteSetting.basic_requires_read_posts
      @regular_requires[:time_read] -= SiteSetting.basic_requires_time_spent_mins
    end
  end

end
