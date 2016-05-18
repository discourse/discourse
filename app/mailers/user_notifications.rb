require_dependency 'markdown_linker'
require_dependency 'email/message_builder'
require_dependency 'age_words'

class UserNotifications < ActionMailer::Base
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

  def mailing_list(user, opts={})
    @since = opts[:since] || 1.day.ago
    @since_formatted = short_date(@since)

    @new_topic_posts      = Post.mailing_list_new_topics(user, @since).group_by(&:topic) || {}
    @existing_topic_posts = Post.mailing_list_updates(user, @since).group_by(&:topic) || {}
    @posts_by_topic       = @new_topic_posts.merge @existing_topic_posts
    return unless @posts_by_topic.present?

    build_summary_for(user)
    build_email @user.email,
                from_alias: I18n.t('user_notifications.mailing_list.from', site_name: SiteSetting.title),
                subject: I18n.t('user_notifications.mailing_list.subject_template',
                                site_name: @site_name,
                                date: @date)
  end

  def digest(user, opts={})
    build_summary_for(user)
    min_date = opts[:since] || @user.last_emailed_at || @user.last_seen_at || 1.month.ago

    @last_seen_at = short_date(@user.last_seen_at || @user.created_at)

    # A list of topics to show the user
    @featured_topics = Topic.for_digest(user, min_date, limit: SiteSetting.digest_topics, top_order: true).to_a

    # Don't send email unless there is content in it
    if @featured_topics.present?
      featured_topic_ids = @featured_topics.map(&:id)

      @new_topics_since_seen = Topic.new_since_last_seen(user, min_date, featured_topic_ids).count
      if @new_topics_since_seen > SiteSetting.digest_topics
        category_counts = Topic.new_since_last_seen(user, min_date, featured_topic_ids).group(:category_id).count

        @new_by_category = []
        if category_counts.present?
          Category.where(id: category_counts.keys).each do |c|
            @new_by_category << [c, category_counts[c.id]]
          end
          @new_by_category.sort_by! {|c| -c[1]}
        end
      end

      @featured_topics, @new_topics = @featured_topics[0..4], @featured_topics[5..-1]

      build_email @user.email,
                  from_alias: I18n.t('user_notifications.digest.from', site_name: SiteSetting.title),
                  subject: I18n.t('user_notifications.digest.subject_template',
                                  site_name: @site_name,
                                  date: short_date(Time.now))
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

    reached_limit = SiteSetting.max_emails_per_day_per_user > 0
    reached_limit &&= (EmailLog.where(user_id: user.id, skipped: false)
                            .where('created_at > ?', 1.day.ago)
                            .count) >= (SiteSetting.max_emails_per_day_per_user-1)

    if opts[:use_invite_template]
      if post.topic.private_message?
        invite_template = "user_notifications.invited_to_private_message_body"
      else
        invite_template = "user_notifications.invited_to_topic_body"
      end
      topic_excerpt = post.excerpt.gsub("\n", " ") if post.is_first_post? && post.excerpt
      message = I18n.t(invite_template, username: username, topic_title: title, topic_excerpt: topic_excerpt, site_title: SiteSetting.title, site_description: SiteSetting.site_description)
      html = UserNotificationRenderer.new(Rails.configuration.paths["app/views"]).render(
        template: 'email/invite',
        format: :html,
        locals: { message: PrettyText.cook(message, sanitize: false).html_safe,
                  classes: RTL.new(user).css_class
        }
      )
    else
      in_reply_to_post = post.reply_to_post if user.user_option.email_in_reply_to
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
      message = email_post_markdown(post) + (reached_limit ? "\n\n#{I18n.t "user_notifications.reached_limit", count: SiteSetting.max_emails_per_day_per_user}" : "");
    end

    template = "user_notifications.user_#{notification_type}"
    if post.topic.private_message?
      template << "_pm"
      template << "_staged" if user.staged?
    end


    email_opts = {
      topic_title: title,
      message: message,
      url: post.url,
      post_id: post.id,
      topic_id: post.topic_id,
      context: context,
      username: username,
      add_unsubscribe_link: !user.staged,
      add_unsubscribe_via_email_link: user.user_option.mailing_list_mode,
      unsubscribe_url: post.topic.unsubscribe_url,
      allow_reply_by_email: allow_reply_by_email,
      only_reply_by_email: allow_reply_by_email && user.staged,
      use_site_subject: use_site_subject,
      add_re_to_subject: add_re_to_subject,
      show_category_in_subject: show_category_in_subject,
      private_reply: post.topic.private_message?,
      include_respond_instructions: !(user.suspended? || user.staged?),
      template: template,
      html_override: html,
      site_description: SiteSetting.site_description,
      site_title: SiteSetting.title,
      style: :notification,
      locale: locale
    }

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
    @site_name       = SiteSetting.email_prefix.presence || SiteSetting.title
    @header_color    = ColorScheme.hex_for_name('header_background')
    @anchor_color    = ColorScheme.hex_for_name('tertiary')
    @markdown_linker = MarkdownLinker.new(@base_url)
    @unsubscribe_key = DigestUnsubscribeKey.create_key_for(@user)
  end
end
