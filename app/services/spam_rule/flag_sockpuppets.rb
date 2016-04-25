class SpamRule::FlagSockpuppets

  def initialize(post)
    @post = post
  end

  def perform
    if SiteSetting.flag_sockpuppets && reply_is_from_sockpuppet?
      flag_sockpuppet_users
      true
    else
      false
    end
  end

  def reply_is_from_sockpuppet?
    return false if @post.try(:post_number) == 1

    first_post = @post.topic.posts.by_post_number.first
    return false if first_post.user.nil?

    !first_post.user.staff? &&
    !@post.user.staff? &&
    !first_post.user.staged? &&
    !@post.user.staged? &&
    @post.user != first_post.user &&
    @post.user.ip_address == first_post.user.ip_address &&
    @post.user.new_user? &&
    !ScreenedIpAddress.is_whitelisted?(@post.user.ip_address)
  end

  def flag_sockpuppet_users
    message = I18n.t('flag_reason.sockpuppet', ip_address: @post.user.ip_address)
    PostAction.act(Discourse.system_user, @post, PostActionType.types[:spam], message: message) rescue PostAction::AlreadyActed

    if (first_post = @post.topic.posts.by_post_number.first).try(:user).try(:new_user?)
      PostAction.act(Discourse.system_user, first_post, PostActionType.types[:spam], message: message) rescue PostAction::AlreadyActed
    end
  end

end
