class SpamRule::AutoBlock

  def initialize(user)
    @user = user
  end

  def self.block?(user)
    self.new(user).block?
  end

  def self.punish!(user)
    self.new(user).block_user
  end

  def perform
    block_user if block?
  end

  def block?
    @user.blocked? or
      (!@user.staged? and
       !@user.has_trust_level?(TrustLevel[1]) and
        SiteSetting.num_flags_to_block_new_user > 0 and
        SiteSetting.num_users_to_block_new_user > 0 and
        num_spam_flags_against_user >= SiteSetting.num_flags_to_block_new_user and
        num_users_who_flagged_spam_against_user >= SiteSetting.num_users_to_block_new_user)
  end

  def num_spam_flags_against_user
    Post.where(user_id: @user.id).sum(:spam_count)
  end

  def num_users_who_flagged_spam_against_user
    post_ids = Post.where('user_id = ? and spam_count > 0', @user.id).pluck(:id)
    return 0 if post_ids.empty?
    PostAction.spam_flags.where(post_id: post_ids).uniq.pluck(:user_id).size
  end

  def block_user
    Post.transaction do
      if UserBlocker.block(@user, Discourse.system_user, message: :too_many_spam_flags) && SiteSetting.notify_mods_when_user_blocked
        GroupMessage.create(Group[:moderators].name, :user_automatically_blocked, {user: @user, limit_once_per: false})
      end
    end
  end
end
