# frozen_string_literal: true

class SpamRule::FlagSockpuppets

  def initialize(post)
    @post = post
  end

  def perform
    I18n.with_locale(SiteSetting.default_locale) do
      if SiteSetting.flag_sockpuppets && reply_is_from_sockpuppet?
        flag_sockpuppet_users
        true
      else
        false
      end
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
    message = I18n.t(
      'flag_reason.sockpuppet',
      ip_address: @post.user.ip_address,
      base_path: Discourse.base_path,
      locale: SiteSetting.default_locale
    )

    PostActionCreator.create(Discourse.system_user, @post, :spam, message: message)

    if (first_post = @post.topic.posts.by_post_number.first).try(:user).try(:new_user?)
      PostActionCreator.create(Discourse.system_user, first_post, :spam, message: message)
    end
  end

end
