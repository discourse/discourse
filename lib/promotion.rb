#
# Check whether a user is ready for a new trust level.
#
class Promotion

  def initialize(user)
    @user = user
  end


  # Review a user for a promotion. Delegates work to a review_#{trust_level} method.
  # Returns true if the user was promoted, false otherwise.
  def review
    # nil users are never promoted
    return false if @user.blank?

    # Promotion beyond basic requires some expensive queries, so don't do that here.
    return false if @user.trust_level >= TrustLevel.levels[:regular]

    trust_key = TrustLevel.levels[@user.trust_level]

    review_method = :"review_#{trust_key.to_s}"
    return send(review_method) if respond_to?(review_method)

    false
  end

  def review_newuser
    Promotion.basic_met?(@user) && change_trust_level!(:basic)
  end

  def review_basic
    Promotion.regular_met?(@user) && change_trust_level!(:regular)
  end

  def review_regular
    Promotion.leader_met?(@user) && change_trust_level!(:leader)
  end

  def change_trust_level!(level, opts = {})
    raise "Invalid trust level #{level}" unless TrustLevel.valid_level?(level)

    old_level = @user.trust_level
    new_level = TrustLevel.levels[level]

    if new_level < old_level
      next_up = TrustLevel.levels[new_level+1]
      key = "#{next_up}_met?"
      if self.class.respond_to?(key) && self.class.send(key, @user)
        raise Discourse::InvalidAccess.new, I18n.t('trust_levels.change_failed_explanation',
             user_name: @user.name,
             new_trust_level: new_level,
             current_trust_level: old_level)
      end
    end

    admin = opts && opts[:log_action_for]

    @user.trust_level = new_level
    @user.user_profile.bio_raw_will_change! # So it can get re-cooked based on the new trust level

    @user.transaction do
      if admin
        StaffActionLogger.new(admin).log_trust_level_change(@user, old_level, new_level)
      end
      @user.save!
      @user.user_profile.recook_bio
      @user.user_profile.save!
      Group.user_trust_level_change!(@user.id, @user.trust_level)
      BadgeGranter.update_badges(action: :trust_level_change, user_id: @user.id)
    end

    true
  end


  def self.regular_met?(user)
    stat = user.user_stat
    return false if stat.topics_entered < SiteSetting.regular_requires_topics_entered
    return false if stat.posts_read_count < SiteSetting.regular_requires_read_posts
    return false if (stat.time_read / 60) < SiteSetting.regular_requires_time_spent_mins
    return false if stat.days_visited < SiteSetting.regular_requires_days_visited
    return false if stat.likes_received < SiteSetting.regular_requires_likes_received
    return false if stat.likes_given < SiteSetting.regular_requires_likes_given
    return false if stat.topic_reply_count < SiteSetting.regular_requires_topic_reply_count

    true
  end

  def self.basic_met?(user)
    stat = user.user_stat
    return false if stat.topics_entered < SiteSetting.basic_requires_topics_entered
    return false if stat.posts_read_count < SiteSetting.basic_requires_read_posts
    return false if (stat.time_read / 60) < SiteSetting.basic_requires_time_spent_mins
    return true
  end

  def self.leader_met?(user)
    LeaderRequirements.new(user).requirements_met?
  end

end
