# frozen_string_literal: true

module DiscoursePolicy::UserNotificationsExtension
  def policy_email(user, opts)
    @user = user
    build_summary_for(user)
    @preferences_path = "#{Discourse.base_url}/my/preferences/emails"

    # TODO(mark.reeves, a la chat plugin): Remove after the 2.9 release
    add_unsubscribe_link = UnsubscribeKey.respond_to?(:get_unsubscribe_strategy_for)

    if add_unsubscribe_link
      unsubscribe_key = UnsubscribeKey.create_key_for(@user, "policy_email")
      @unsubscribe_link = "#{Discourse.base_url}/email/unsubscribe/#{unsubscribe_key}"
      opts[:add_unsubscribe_link] = add_unsubscribe_link
    end

    @post = opts[:post]
    @topic_title = @post.topic.title
    @classes = Rtl.new(user).css_class
    @base_url = Discourse.base_url
    @first_footer_classes = "highlight"
    opts[:subject] = I18n.t("user_notifications.policy_email.subject", topic_title: @topic_title)

    build_email(user.email, opts)
  end
end
