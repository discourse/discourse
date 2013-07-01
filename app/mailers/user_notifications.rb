require_dependency 'markdown_linker'
require_dependency 'email/message_builder'

class UserNotifications < ActionMailer::Base
  default charset: 'UTF-8'

  include Email::BuildEmailHelper

  def signup(user, opts={})
    build_email(user.email,
                template: "user_notifications.signup",
                email_token: opts[:email_token])
  end

  def signup_after_approval(user, opts={})
    build_email(user.email,
                template: 'user_notifications.signup_after_approval',
                email_token: opts[:email_token],
                new_user_tips: SiteContent.content_for(:usage_tips))
  end

  def authorize_email(user, opts={})
    build_email(user.email, template: "user_notifications.authorize_email", email_token: opts[:email_token])
  end

  def forgot_password(user, opts={})
    build_email(user.email, template: "user_notifications.forgot_password", email_token: opts[:email_token])
  end

  def private_message(user, opts={})
    post = opts[:post]

    build_email user.email,
                template: "user_notifications.private_message",
                message: post.raw,
                url: post.url,
                subject_prefix: "[#{I18n.t('private_message_abbrev')}] #{post.post_number != 1 ? 're: ' : ''}",
                topic_title: post.topic.title,
                private_message_from: post.user.name,
                from_alias: I18n.t(:via, username: post.user.name, site_name: SiteSetting.title),
                add_unsubscribe_link: true,
                allow_reply_by_email: true,
                post_id: post.id,
                topic_id: post.topic_id
  end

  def digest(user, opts={})
    @user = user
    @base_url = Discourse.base_url

    min_date = opts[:since] || @user.last_emailed_at || @user.last_seen_at || 1.month.ago

    @site_name = SiteSetting.title

    @last_seen_at = I18n.l(@user.last_seen_at || @user.created_at, format: :short)

    # A list of topics to show the user
    @new_topics = Topic.for_digest(user, min_date)
    @markdown_linker = MarkdownLinker.new(Discourse.base_url)

    # Don't send email unless there is content in it
    if @new_topics.present?
      build_email user.email,
                  from_alias: I18n.t('user_notifications.digest.from', site_name: SiteSetting.title),
                  subject: I18n.t('user_notifications.digest.subject_template',
                  site_name: @site_name,
                  date: I18n.l(Time.now, format: :short))
    end
  end

  def user_invited_to_private_message(user, opts)
    notification_email(user, opts)
  end

  def user_replied(user, opts)
    opts[:allow_reply_by_email] = true
    notification_email(user, opts)
  end

  def user_quoted(user, opts)
    opts[:allow_reply_by_email] = true
    notification_email(user, opts)
  end

  def user_mentioned(user, opts)
    opts[:allow_reply_by_email] = true
    notification_email(user, opts)
  end

  def user_posted(user, opts)
    opts[:allow_reply_by_email] = true
    notification_email(user, opts)
  end

  protected

  def notification_email(user, opts)
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
      post_id: @post.id,
      topic_id: @post.topic_id,
      username: username,
      add_unsubscribe_link: true,
      allow_reply_by_email: opts[:allow_reply_by_email],
      template: "user_notifications.user_#{notification_type}"
    }

    # If we have a display name, change the from address
    if username.present?
      email_opts[:from_alias] = I18n.t(:via, username: username, site_name: SiteSetting.title)
    end

    build_email(user.email, email_opts)
  end



end
