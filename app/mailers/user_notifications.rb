require_dependency 'markdown_linker'
require_dependency 'email_builder'

class UserNotifications < ActionMailer::Base
  default charset: 'UTF-8'

  include EmailBuilder

  def signup(user, opts={})
    build_email(user.email, "user_notifications.signup", email_token: opts[:email_token])
  end

  def authorize_email(user, opts={})
    build_email(user.email, "user_notifications.authorize_email", email_token: opts[:email_token])
  end

  def forgot_password(user, opts={})
    build_email(user.email, "user_notifications.forgot_password", email_token: opts[:email_token])
  end

  def private_message(user, opts={})
    post = opts[:post]

    build_email user.email,
                "user_notifications.private_message",
                message: post.raw,
                url: post.url,
                subject_prefix: post.post_number != 1 ? "re: " : "",
                topic_title: post.topic.title,
                private_message_from: post.user.name,
                from: "#{I18n.t(:via, username: post.user.name, site_name: SiteSetting.title)} <#{SiteSetting.notification_email}>",
                add_unsubscribe_link: true
  end

  def digest(user, opts={})
    @user = user
    @base_url = Discourse.base_url

    min_date = @user.last_emailed_at || @user.last_seen_at || 1.month.ago

    @site_name = SiteSetting.title

    @last_seen_at = I18n.l(@user.last_seen_at || @user.created_at, format: :short)

    # A list of new topics to show the user
    @new_topics = Topic.new_topics(min_date)
    @notifications = @user.notifications.interesting_after(min_date)

    @markdown_linker = MarkdownLinker.new(Discourse.base_url)

    # Don't send email unless there is content in it
    if @new_topics.present? || @notifications.present?
      mail to: user.email,
           from: "#{I18n.t('user_notifications.digest.from', site_name: SiteSetting.title)} <#{SiteSetting.notification_email}>",
           subject: I18n.t('user_notifications.digest.subject_template',
                            site_name: @site_name,
                            date: I18n.l(Time.now, format: :short))
    end
  end

  def notification_template(user, opts)
    @notification = opts[:notification]
    return unless @notification.present?

    @post = opts[:post]
    return unless @post.present?

    username = @notification.data_hash[:display_username]
    notification_type = Notification.types[opts[:notification].notification_type].to_s

    email_opts = {
      topic_title: @notification.data_hash[:topic_title],
      message: @post.raw,
      url: @post.url,
      username: username,
      add_unsubscribe_link: true
    }

    # If we have a display name, change the from address
    if username.present?
      aliased = I18n.t(:via, username: username, site_name: SiteSetting.title)
      email_opts[:from] = "#{aliased} <#{SiteSetting.notification_email}>"
    end

    email = build_email user.email, "user_notifications.user_#{notification_type}", email_opts
  end

  alias :user_invited_to_private_message :notification_template
  alias :user_replied :notification_template
  alias :user_quoted :notification_template
  alias :user_mentioned :notification_template
  alias :user_posted :notification_template

end
