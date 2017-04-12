require_dependency 'markdown_linker'
require_dependency 'email/message_builder'
require_dependency 'age_words'

class UserNotifications < ActionMailer::Base
  include UserNotificationsHelper
  include ApplicationHelper
  helper :application
  default charset: 'UTF-8'

  include Email::BuildEmailHelper

  def signup(user, opts={})
    build_email(user.email,
                template: "user_notifications.signup",
                locale: user_locale(user),
                email_token: opts[:email_token])
  end

  def signup_after_approval(user, opts={})
    build_email(user.email,
                template: 'user_notifications.signup_after_approval',
                locale: user_locale(user),
                email_token: opts[:email_token],
                new_user_tips: I18n.t('system_messages.usage_tips.text_body_template', base_url: Discourse.base_url, locale: locale))
  end

  def notify_old_email(user, opts={})
    build_email(user.email,
                template: "user_notifications.notify_old_email",
                locale: user_locale(user),
                new_email: opts[:new_email])
  end

  def confirm_old_email(user, opts={})
    build_email(user.email,
                template: "user_notifications.confirm_old_email",
                locale: user_locale(user),
                email_token: opts[:email_token])
  end

  def confirm_new_email(user, opts={})
    build_email(user.email,
                template: "user_notifications.confirm_new_email",
                locale: user_locale(user),
                email_token: opts[:email_token])
  end

  def forgot_password(user, opts={})
    build_email(user.email,
                template: user.has_password? ? "user_notifications.forgot_password" : "user_notifications.set_password",
                locale: user_locale(user),
                email_token: opts[:email_token])
  end

  def admin_login(user, opts={})
    build_email(user.email,
                template: "user_notifications.admin_login",
                locale: user_locale(user),
                email_token: opts[:email_token])
  end

  def account_created(user, opts={})
    build_email(user.email,
                template: "user_notifications.account_created",
                locale: user_locale(user),
                email_token: opts[:email_token])
  end

  def short_date(dt)
    if dt.year == Time.now.year
      I18n.l(dt, format: :short_no_year)
    else
      I18n.l(dt, format: :date_only)
    end
  end

  # This is the "mailing list summary email"
  def mailing_list(user, opts={})
    @since = opts[:since] || 1.day.ago
    @since_formatted = short_date(@since)

    @new_topic_posts      = Post.mailing_list_new_topics(user, @since).group_by(&:topic) || {}
    @existing_topic_posts = Post.mailing_list_updates(user, @since).group_by(&:topic) || {}
    @posts_by_topic       = @new_topic_posts.merge @existing_topic_posts
    return unless @posts_by_topic.present?

    build_summary_for(user)
    opts = {
      from_alias: I18n.t('user_notifications.mailing_list.from', site_name: SiteSetting.title),
      subject: I18n.t('user_notifications.mailing_list.subject_template', email_prefix: @email_prefix, date: @date),
      mailing_list_mode: true,
      add_unsubscribe_link: true,
      unsubscribe_url: "#{Discourse.base_url}/email/unsubscribe/#{@unsubscribe_key}",
    }
    apply_notification_styles(build_email(@user.email, opts))
  end

  def digest(user, opts={})
    build_summary_for(user)
    min_date = opts[:since] || user.last_emailed_at || user.last_seen_at || 1.month.ago

    # Fetch some topics and posts to show
    digest_opts = {limit: SiteSetting.digest_topics + SiteSetting.digest_other_topics, top_order: true}
    topics_for_digest = Topic.for_digest(user, min_date, digest_opts).to_a
    if topics_for_digest.empty? && !user.user_option.try(:include_tl0_in_digests)
      # Find some topics from new users that are at least 24 hours old
      topics_for_digest = Topic.for_digest(user, min_date, digest_opts.merge(include_tl0: true)).where('topics.created_at < ?', 24.hours.ago).to_a
    end

    @popular_topics = topics_for_digest[0,SiteSetting.digest_topics]

    if @popular_topics.present?
      @other_new_for_you = topics_for_digest.size > SiteSetting.digest_topics ? topics_for_digest[SiteSetting.digest_topics..-1] : []

      @popular_posts = if SiteSetting.digest_posts > 0
        Post.order("posts.score DESC")
            .for_mailing_list(user, min_date)
            .where('posts.post_type = ?', Post.types[:regular])
            .where('posts.deleted_at IS NULL AND posts.hidden = false AND posts.user_deleted = false')
            .where("posts.post_number > ? AND posts.score > ?", 1, ScoreCalculator.default_score_weights[:like_score] * 5.0)
            .limit(SiteSetting.digest_posts)
      else
        []
      end

      @excerpts = {}

      @popular_topics.map do |t|
        @excerpts[t.first_post.id] = email_excerpt(t.first_post.cooked) if t.first_post.present?
      end

      # Try to find 3 interesting stats for the top of the digest

      new_topics_count = Topic.new_since_last_seen(user, min_date).count
      if new_topics_count == 0
        # We used topics from new users instead, so count should match
        new_topics_count = topics_for_digest.size
      end
      @counts = [{label_key: 'user_notifications.digest.new_topics',
                  value: new_topics_count,
                  href: "#{Discourse.base_url}/new"}]

      value = user.unread_notifications
      @counts << {label_key: 'user_notifications.digest.unread_notifications', value: value, href: "#{Discourse.base_url}/my/notifications"} if value > 0

      value = user.unread_private_messages
      @counts << {label_key: 'user_notifications.digest.unread_messages', value: value, href: "#{Discourse.base_url}/my/messages"} if value > 0

      if @counts.size < 3
        value = user.unread_notifications_of_type(Notification.types[:liked])
        @counts << {label_key: 'user_notifications.digest.liked_received', value: value, href: "#{Discourse.base_url}/my/notifications"} if value > 0
      end

      if @counts.size < 3
        value = Post.for_mailing_list(user, min_date).where("posts.post_number > ?", 1).count
        @counts << { label_key: 'user_notifications.digest.new_posts', value: value, href: "#{Discourse.base_url}/new" } if value > 0
      end

      if @counts.size < 3
        value = User.real.where(active: true, staged: false).not_suspended.where("created_at > ?", min_date).count
        @counts << { label_key: 'user_notifications.digest.new_users', value: value, href: "#{Discourse.base_url}/about" } if value > 0
      end

      @last_seen_at = short_date(user.last_seen_at || user.created_at)

      @preheader_text = I18n.t('user_notifications.digest.preheader', last_seen_at: @last_seen_at)

      opts = {
        from_alias: I18n.t('user_notifications.digest.from', site_name: SiteSetting.title),
        subject: I18n.t('user_notifications.digest.subject_template', email_prefix: @email_prefix, date: short_date(Time.now)),
        add_unsubscribe_link: true,
        unsubscribe_url: "#{Discourse.base_url}/email/unsubscribe/#{@unsubscribe_key}",
      }

      build_email(user.email, opts)
    end
  end


  def user_replied(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    notification_email(user, opts)
  end

  def user_quoted(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    notification_email(user, opts)
  end

  def user_linked(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    notification_email(user, opts)
  end

  def user_mentioned(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    notification_email(user, opts)
  end

  def group_mentioned(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    notification_email(user, opts)
  end

  def user_posted(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:add_re_to_subject] = true
    opts[:show_category_in_subject] = true
    notification_email(user, opts)
  end

  def user_private_message(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:add_re_to_subject] = true
    opts[:show_category_in_subject] = false

    # We use the 'user_posted' event when you are emailed a post in a PM.
    opts[:notification_type] = 'posted'

    notification_email(user, opts)
  end

  def user_invited_to_private_message(user, opts)
    opts[:allow_reply_by_email] = false
    opts[:use_invite_template] = true
    notification_email(user, opts)
  end

  def user_invited_to_topic(user, opts)
    opts[:allow_reply_by_email] = false
    opts[:use_invite_template] = true
    opts[:show_category_in_subject] = true
    notification_email(user, opts)
  end

  def user_watching_first_post(user, opts)
    user_posted(user, opts)
  end

  def mailing_list_notify(user, post)
    opts = {
      post: post,
      allow_reply_by_email: true,
      use_site_subject: true,
      add_re_to_subject: true,
      show_category_in_subject: true,
      notification_type: "posted",
      notification_data_hash: {
        original_username: post.user.username,
        topic_title: post.topic.title,
      },
    }
    notification_email(user, opts)
  end

  protected

  def user_locale(user)
    (user.locale.present? && I18n.available_locales.include?(user.locale.to_sym)) ? user.locale : nil
  end

  def email_post_markdown(post, add_posted_by=false)
    result = "[email-indent]\n"
    result << "#{post.raw}\n\n"
    if add_posted_by
      result << "#{I18n.t('user_notifications.posted_by', username: post.username, post_date: post.created_at.strftime("%m/%d/%Y"))}\n\n"
    end
    result << "[/email-indent]\n"
    result
  end

  class UserNotificationRenderer < ActionView::Base
    include UserNotificationsHelper
  end

  def self.get_context_posts(post, topic_user, user)
    if user.user_option.email_previous_replies == UserOption.previous_replies_type[:never]
      return []
    end

    allowed_post_types = [Post.types[:regular]]
    allowed_post_types << Post.types[:whisper] if topic_user.try(:user).try(:staff?)

    context_posts = Post.where(topic_id: post.topic_id)
                        .where("post_number < ?", post.post_number)
                        .where(user_deleted: false)
                        .where(hidden: false)
                        .where(post_type: allowed_post_types)
                        .order('created_at desc')
                        .limit(SiteSetting.email_posts_context)

    if topic_user && topic_user.last_emailed_post_number && user.user_option.email_previous_replies == UserOption.previous_replies_type[:unless_emailed]
      context_posts = context_posts.where("post_number > ?", topic_user.last_emailed_post_number)
    end

    context_posts
  end

  def notification_email(user, opts)
    notification_type = opts[:notification_type]
    notification_data = opts[:notification_data_hash]
    post = opts[:post]

    unless String === notification_type
      if Numeric === notification_type
        notification_type = Notification.types[notification_type]
      end
      notification_type = notification_type.to_s
    end

    user_name = notification_data[:original_username]

    if post && SiteSetting.enable_names && SiteSetting.display_name_on_email_from
      name = User.where(id: post.user_id).pluck(:name).first
      user_name = name unless name.blank?
    end

    allow_reply_by_email = opts[:allow_reply_by_email] unless user.suspended?
    original_username = notification_data[:original_username] || notification_data[:display_username]

    send_notification_email(
      title: notification_data[:topic_title],
      post: post,
      username: original_username,
      from_alias: user_name,
      allow_reply_by_email: allow_reply_by_email,
      use_site_subject: opts[:use_site_subject],
      add_re_to_subject: opts[:add_re_to_subject],
      show_category_in_subject: opts[:show_category_in_subject],
      notification_type: notification_type,
      use_invite_template: opts[:use_invite_template],
      user: user
    )
  end

  def send_notification_email(opts)
    post = opts[:post]
    title = opts[:title]
    allow_reply_by_email = opts[:allow_reply_by_email]
    use_site_subject = opts[:use_site_subject]
    add_re_to_subject = opts[:add_re_to_subject] && post.post_number > 1
    username = opts[:username]
    from_alias = opts[:from_alias]
    notification_type = opts[:notification_type]
    user = opts[:user]
    locale = user_locale(user)

    template = "user_notifications.user_#{notification_type}"
    if post.topic.private_message?
      template << "_pm"
      template << "_staged" if user.staged?
    end

    # category name
    category = Topic.find_by(id: post.topic_id).category
    if opts[:show_category_in_subject] && post.topic_id && category && !category.uncategorized?
      show_category_in_subject = category.name

      # subcategory case
      if !category.parent_category_id.nil?
        show_category_in_subject = "#{Category.find_by(id: category.parent_category_id).name}/#{show_category_in_subject}"
      end
    else
      show_category_in_subject = nil
    end

    context = ""
    tu = TopicUser.get(post.topic_id, user)
    context_posts = self.class.get_context_posts(post, tu, user)

    # make .present? cheaper
    context_posts = context_posts.to_a

    if context_posts.present?
      context << "-- \n*#{I18n.t('user_notifications.previous_discussion')}*\n"
      context_posts.each do |cp|
        context << email_post_markdown(cp, true)
      end
    end

    translation_override_exists = TranslationOverride.where(locale: SiteSetting.default_locale, translation_key: "#{template}.text_body_template").exists?

    if opts[:use_invite_template]
      if post.topic.private_message?
        invite_template = "user_notifications.invited_to_private_message_body"
      else
        invite_template = "user_notifications.invited_to_topic_body"
      end
      topic_excerpt = post.excerpt.tr("\n", " ") if post.is_first_post? && post.excerpt
      message = I18n.t(invite_template, username: username, topic_title: gsub_emoji_to_unicode(title), topic_excerpt: topic_excerpt, site_title: SiteSetting.title, site_description: SiteSetting.site_description)

      unless translation_override_exists
        html = UserNotificationRenderer.new(Rails.configuration.paths["app/views"]).render(
          template: 'email/invite',
          format: :html,
          locals: { message: PrettyText.cook(message, sanitize: false).html_safe,
                    classes: RTL.new(user).css_class
          }
        )
      end
    else
      reached_limit = SiteSetting.max_emails_per_day_per_user > 0
      reached_limit &&= (EmailLog.where(user_id: user.id, skipped: false)
                              .where('created_at > ?', 1.day.ago)
                              .count) >= (SiteSetting.max_emails_per_day_per_user-1)

      in_reply_to_post = post.reply_to_post if user.user_option.email_in_reply_to
      message = email_post_markdown(post) + (reached_limit ? "\n\n#{I18n.t "user_notifications.reached_limit", count: SiteSetting.max_emails_per_day_per_user}" : "");

      unless translation_override_exists
        html = UserNotificationRenderer.new(Rails.configuration.paths["app/views"]).render(
          template: 'email/notification',
          format: :html,
          locals: { context_posts: context_posts,
                    reached_limit: reached_limit,
                    post: post,
                    in_reply_to_post: in_reply_to_post,
                    classes: RTL.new(user).css_class
          }
        )
      end
    end

    email_opts = {
      topic_title: gsub_emoji_to_unicode(title),
      topic_title_url_encoded: title ? URI.encode(title) : title,
      message: message,
      url: post.url,
      post_id: post.id,
      topic_id: post.topic_id,
      context: context,
      username: username,
      add_unsubscribe_link: !user.staged,
      mailing_list_mode: user.user_option.mailing_list_mode,
      unsubscribe_url: post.unsubscribe_url(user),
      allow_reply_by_email: allow_reply_by_email,
      only_reply_by_email: allow_reply_by_email && user.staged,
      use_site_subject: use_site_subject,
      add_re_to_subject: add_re_to_subject,
      show_category_in_subject: show_category_in_subject,
      private_reply: post.topic.private_message?,
      include_respond_instructions: !(user.suspended? || user.staged?),
      template: template,
      site_description: SiteSetting.site_description,
      site_title: SiteSetting.title,
      site_title_url_encoded: URI.encode(SiteSetting.title),
      style: :notification,
      locale: locale
    }

    unless translation_override_exists
      email_opts[:html_override] = html
    end

    # If we have a display name, change the from address
    email_opts[:from_alias] = from_alias if from_alias.present?

    TopicUser.change(user.id, post.topic_id, last_emailed_post_number: post.post_number)

    build_email(user.email, email_opts)
  end

  private

  def build_summary_for(user)
    @user            = user
    @date            = short_date(Time.now)
    @base_url        = Discourse.base_url
    @email_prefix    = SiteSetting.email_prefix.presence || SiteSetting.title
    @header_color    = ColorScheme.hex_for_name('header_primary')
    @header_bgcolor  = ColorScheme.hex_for_name('header_background')
    @anchor_color    = ColorScheme.hex_for_name('tertiary')
    @markdown_linker = MarkdownLinker.new(@base_url)
    @unsubscribe_key = UnsubscribeKey.create_key_for(@user, "digest")
  end

  def apply_notification_styles(email)
    email.html_part.body = Email::Styles.new(email.html_part.body.to_s).tap do |styles|
      styles.format_basic
      styles.format_notification
    end.to_html
    email
  end
end
