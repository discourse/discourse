# The SpamRulesEnforcer class takes action against users based on flags that their posts
# receive, their trust level, etc.
class SpamRulesEnforcer

  include Rails.application.routes.url_helpers

  # The exclamation point means that this method may make big changes to posts and users.
  def self.enforce!(arg)
    SpamRulesEnforcer.new(arg).enforce!
  end

  def initialize(arg)
    @user = arg if arg.is_a?(User)
    @post = arg if arg.is_a?(Post)
  end

  def enforce!
    # TODO: once rules are in their own classes, invoke them from here in priority order
    if @user
      block_user if block?
    end
    if @post
      flag_sockpuppet_users if SiteSetting.flag_sockpuppets and reply_is_from_sockpuppet?
    end
    true
  end

  # TODO: move this sockpuppet code to its own class. We should be able to add more rules, like ActiveModel validators.
  def reply_is_from_sockpuppet?
    return false if @post.post_number and @post.post_number == 1

    first_post = @post.topic.posts.by_post_number.first
    return false if first_post.user.nil?

    !first_post.user.staff? and !@post.user.staff? and
      @post.user != first_post.user and
      @post.user.ip_address == first_post.user.ip_address and
      @post.user.new_user?
  end

  def flag_sockpuppet_users
    system_user = Discourse.system_user
    PostAction.act(system_user, @post, PostActionType.types[:spam], message: I18n.t('flag_reason.sockpuppet')) rescue PostAction::AlreadyActed
    if (first_post = @post.topic.posts.by_post_number.first).try(:user).try(:new_user?)
      PostAction.act(system_user, first_post, PostActionType.types[:spam], message: I18n.t('flag_reason.sockpuppet')) rescue PostAction::AlreadyActed
    end
  end

  # TODO: move all this auto-block code to another class:
  def self.block?(user)
    SpamRulesEnforcer.new(user).block?
  end

  def self.punish!(user)
    SpamRulesEnforcer.new(user).block_user
  end

  def block?
    @user.blocked? or
      (!@user.has_trust_level?(:basic) and
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
      if UserBlocker.block(@user, nil, {message: :too_many_spam_flags}) and SiteSetting.notify_mods_when_user_blocked
        GroupMessage.create(Group[:moderators].name, :user_automatically_blocked, {user: @user, limit_once_per: false})
      end
    end
  end


end
