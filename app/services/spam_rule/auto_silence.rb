class SpamRule::AutoSilence

  def initialize(user)
    @user = user
  end

  def self.silence?(user)
    self.new(user).silence?
  end

  def self.punish!(user)
    self.new(user).silence_user
  end

  def perform
    silence_user if silence?
  end

  def silence?
    return true if @user.silenced?
    return false if @user.staged?
    return false if @user.has_trust_level?(TrustLevel[1])

    if SiteSetting.num_spam_flags_to_silence_new_user > (0) &&
        SiteSetting.num_users_to_silence_new_user > (0) &&
        num_spam_flags_against_user >= (SiteSetting.num_spam_flags_to_silence_new_user) &&
        num_users_who_flagged_spam_against_user >= (SiteSetting.num_users_to_silence_new_user)
      return true
    end

    if SiteSetting.num_tl3_flags_to_silence_new_user > (0) &&
        SiteSetting.num_tl3_users_to_silence_new_user > (0) &&
        num_tl3_flags_against_user >= (SiteSetting.num_tl3_flags_to_silence_new_user) &&
        num_tl3_users_who_flagged >= (SiteSetting.num_tl3_users_to_silence_new_user)
      return true
    end

    false
  end

  def num_spam_flags_against_user
    Post.where(user_id: @user.id).sum(:spam_count)
  end

  def num_users_who_flagged_spam_against_user
    post_ids = Post.where('user_id = ? and spam_count > 0', @user.id).pluck(:id)
    return 0 if post_ids.empty?
    PostAction.spam_flags.where(post_id: post_ids).pluck(:user_id).uniq.size
  end

  def num_tl3_flags_against_user
    if flagged_post_ids.empty?
      0
    else
      PostAction.where(post_id: flagged_post_ids).joins(:user).where('users.trust_level >= ?', 3).count
    end
  end

  def num_tl3_users_who_flagged
    if flagged_post_ids.empty?
      0
    else
      PostAction.where(post_id: flagged_post_ids).joins(:user).where('users.trust_level >= ?', 3).pluck(:user_id).uniq.size
    end
  end

  def flagged_post_ids
    Post.where(user_id: @user.id)
      .where('spam_count > 0 OR off_topic_count > 0 OR inappropriate_count > 0')
      .pluck(:id)
  end

  def silence_user
    Post.transaction do
      if UserSilencer.silence(@user, Discourse.system_user, message: :too_many_spam_flags) && SiteSetting.notify_mods_when_user_silenced
        GroupMessage.create(Group[:moderators].name, :user_automatically_silenced, user: @user, limit_once_per: false)
      end
    end
  end
end
