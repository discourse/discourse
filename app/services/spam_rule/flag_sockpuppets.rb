class SpamRule::FlagSockpuppets

  def initialize(post)
    @post = post
  end

  def perform
    if SiteSetting.flag_sockpuppets and reply_is_from_sockpuppet?
      flag_sockpuppet_users
      true
    else
      false
    end
  end

  def reply_is_from_sockpuppet?
    return false if @post.post_number and @post.post_number == 1

    first_post = @post.topic.posts.by_post_number.first
    return false if first_post.user.nil?

    !first_post.user.staff? and !@post.user.staff? and
      @post.user != first_post.user and
      @post.user.ip_address == first_post.user.ip_address and
      @post.user.new_user? and
      !ScreenedIpAddress.is_whitelisted?(@post.user.ip_address)
  end

  def flag_sockpuppet_users
    system_user = Discourse.system_user
    PostAction.act(system_user, @post, PostActionType.types[:spam], message: I18n.t('flag_reason.sockpuppet')) rescue PostAction::AlreadyActed
    if (first_post = @post.topic.posts.by_post_number.first).try(:user).try(:new_user?)
      PostAction.act(system_user, first_post, PostActionType.types[:spam], message: I18n.t('flag_reason.sockpuppet')) rescue PostAction::AlreadyActed
    end
  end

end