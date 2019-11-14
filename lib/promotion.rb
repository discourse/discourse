# frozen_string_literal: true

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
    return false if @user.blank? || !@user.manual_locked_trust_level.nil?

    # Promotion beyond basic requires some expensive queries, so don't do that here.
    return false if @user.trust_level >= TrustLevel[2]

    review_method = :"review_tl#{@user.trust_level}"
    return public_send(review_method) if respond_to?(review_method)

    false
  end

  def review_tl0
    if Promotion.tl1_met?(@user) && change_trust_level!(TrustLevel[1])
      @user.enqueue_member_welcome_message unless @user.badges.where(id: Badge::BasicUser).count > 0
      return true
    end
    false
  end

  def review_tl1
    Promotion.tl2_met?(@user) && change_trust_level!(TrustLevel[2])
  end

  def review_tl2
    Promotion.tl3_met?(@user) && change_trust_level!(TrustLevel[3])
  end

  def change_trust_level!(level, opts = {})
    raise "Invalid trust level #{level}" unless TrustLevel.valid?(level)

    old_level = @user.trust_level
    new_level = level

    if new_level < old_level && @user.manual_locked_trust_level.nil?
      next_up = new_level + 1
      key = "tl#{next_up}_met?"
      if self.class.respond_to?(key) && self.class.public_send(key, @user)
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
      else
        UserHistory.create!(action: UserHistory.actions[:auto_trust_level_change],
                            target_user_id: @user.id,
                            previous_value: old_level,
                            new_value: new_level)
      end
      @user.save!
      @user.user_profile.recook_bio
      @user.user_profile.save!
      DiscourseEvent.trigger(:user_promoted, user_id: @user.id, new_trust_level: new_level, old_trust_level: old_level)
      Group.user_trust_level_change!(@user.id, @user.trust_level)
      BadgeGranter.queue_badge_grant(Badge::Trigger::TrustLevelChange, user: @user)
    end

    true
  end

  def self.tl2_met?(user)
    stat = user.user_stat
    return false if stat.topics_entered < SiteSetting.tl2_requires_topics_entered
    return false if stat.posts_read_count < SiteSetting.tl2_requires_read_posts
    return false if (stat.time_read / 60) < SiteSetting.tl2_requires_time_spent_mins
    return false if ((Time.now - user.created_at) / 60) < SiteSetting.tl2_requires_time_spent_mins
    return false if stat.days_visited < SiteSetting.tl2_requires_days_visited
    return false if stat.likes_received < SiteSetting.tl2_requires_likes_received
    return false if stat.likes_given < SiteSetting.tl2_requires_likes_given
    return false if stat.topic_reply_count < SiteSetting.tl2_requires_topic_reply_count

    true
  end

  def self.tl1_met?(user)
    stat = user.user_stat
    return false if stat.topics_entered < SiteSetting.tl1_requires_topics_entered
    return false if stat.posts_read_count < SiteSetting.tl1_requires_read_posts
    return false if (stat.time_read / 60) < SiteSetting.tl1_requires_time_spent_mins
    return false if ((Time.now - user.created_at) / 60) < SiteSetting.tl1_requires_time_spent_mins

    true
  end

  def self.tl3_met?(user)
    TrustLevel3Requirements.new(user).requirements_met?
  end

  def self.tl3_lost?(user)
    TrustLevel3Requirements.new(user).requirements_lost?
  end

  # Figure out what a user's trust level should be from scratch
  def self.recalculate(user, performed_by = nil)
    # First, use the manual locked level
    unless user.manual_locked_trust_level.nil?
      return user.update!(
        trust_level: user.manual_locked_trust_level
      )
    end

    # Then consider the group locked level
    user_group_granted_trust_level = user.group_granted_trust_level

    unless user_group_granted_trust_level.blank?
      return user.update!(
        trust_level: user_group_granted_trust_level
      )
    end

    user.update_column(:trust_level, TrustLevel[0])

    p = Promotion.new(user)
    p.review_tl0
    p.review_tl1
    p.review_tl2
    if user.trust_level == 3 && Promotion.tl3_lost?(user)
      user.change_trust_level!(2, log_action_for: performed_by || Discourse.system_user)
    end
  end
end
