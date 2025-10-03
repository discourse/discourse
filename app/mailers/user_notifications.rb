# frozen_string_literal: true

class UserNotifications < ActionMailer::Base
  include UserNotificationsHelper
  include ApplicationHelper
  helper :application, :email
  default charset: "UTF-8"
  layout "email_template"

  include Email::BuildEmailHelper

  def signup(user, opts = {})
    build_user_email_token_by_template("user_notifications.signup", user, opts[:email_token])
  end

  def activation_reminder(user, opts = {})
    build_user_email_token_by_template(
      "user_notifications.activation_reminder",
      user,
      opts[:email_token],
    )
  end

  def signup_after_approval(user, opts = {})
    locale = user_locale(user)
    tips =
      I18n.t(
        "system_messages.usage_tips.text_body_template",
        base_url: Discourse.base_url,
        locale: locale,
      )

    build_email(
      user.email,
      template: "user_notifications.signup_after_approval",
      locale: locale,
      new_user_tips: tips,
    )
  end

  def post_approved(user, opts = {})
    post_url = opts.dig(:notification_data_hash, :post_url)

    return if post_url.nil?

    locale = user_locale(user)
    build_email(
      user.email,
      template: "user_notifications.post_approved",
      locale: locale,
      base_url: Discourse.base_url,
      post_url: post_url,
    )
  end

  def signup_after_reject(user, opts = {})
    locale = user_locale(user)
    build_email(
      user.email,
      template: "user_notifications.signup_after_reject",
      locale: locale,
      reject_reason: opts[:reject_reason],
    )
  end

  def suspicious_login(user, opts = {})
    ipinfo = DiscourseIpInfo.get(opts[:client_ip])
    location = ipinfo[:location]
    browser = BrowserDetection.browser(opts[:user_agent])
    device = BrowserDetection.device(opts[:user_agent])
    os = BrowserDetection.os(opts[:user_agent])

    build_email(
      user.email,
      template: "user_notifications.suspicious_login",
      locale: user_locale(user),
      client_ip: opts[:client_ip],
      location: location.present? ? location : I18n.t("staff_action_logs.unknown"),
      browser: I18n.t("user_auth_tokens.browser.#{browser}"),
      device: I18n.t("user_auth_tokens.device.#{device}"),
      os: I18n.t("user_auth_tokens.os.#{os}"),
    )
  end

  def notify_old_email(user, opts = {})
    build_email(
      user.email,
      template: "user_notifications.notify_old_email",
      locale: user_locale(user),
      new_email: opts[:new_email],
    )
  end

  def notify_old_email_add(user, opts = {})
    build_email(
      user.email,
      template: "user_notifications.notify_old_email_add",
      locale: user_locale(user),
      new_email: opts[:new_email],
    )
  end

  def confirm_old_email(user, opts = {})
    build_user_email_token_by_template(
      "user_notifications.confirm_old_email",
      user,
      opts[:email_token],
    )
  end

  def confirm_old_email_add(user, opts = {})
    build_user_email_token_by_template(
      "user_notifications.confirm_old_email_add",
      user,
      opts[:email_token],
    )
  end

  def confirm_new_email(user, opts = {})
    build_user_email_token_by_template(
      (
        if opts[:requested_by_admin]
          "user_notifications.confirm_new_email_via_admin"
        else
          "user_notifications.confirm_new_email"
        end
      ),
      user,
      opts[:email_token],
    )
  end

  def forgot_password(user, opts = {})
    build_user_email_token_by_template(
      user.has_password? ? "user_notifications.forgot_password" : "user_notifications.set_password",
      user,
      opts[:email_token],
    )
  end

  def email_login(user, opts = {})
    build_user_email_token_by_template("user_notifications.email_login", user, opts[:email_token])
  end

  def admin_login(user, opts = {})
    build_user_email_token_by_template("user_notifications.admin_login", user, opts[:email_token])
  end

  def account_created(user, opts = {})
    build_user_email_token_by_template(
      "user_notifications.account_created",
      user,
      opts[:email_token],
    )
  end

  def account_silenced(user, opts = nil)
    opts ||= {}

    return unless user_history = opts[:user_history]

    if user.silenced_forever?
      build_email(
        user.email,
        template: "user_notifications.account_silenced_forever",
        locale: user_locale(user),
        reason: user_history.details,
      )
    else
      silenced_till = user.silenced_till.in_time_zone(user.user_option.timezone.presence || "UTC")
      build_email(
        user.email,
        template: "user_notifications.account_silenced",
        locale: user_locale(user),
        reason: user_history.details,
        silenced_till: I18n.l(silenced_till, format: :long),
      )
    end
  end

  def account_deleted(email, reviewable)
    post_action_type_id =
      reviewable.reviewable_scores.first&.reviewable_score_type ||
        PostActionTypeView.new.types[:spam]
    build_email(
      email,
      template: "user_notifications.account_deleted",
      flag_reason: I18n.t("flag_reasons.#{PostActionTypeView.new.types[post_action_type_id]}"),
    )
  end

  def account_suspended(user, opts = nil)
    opts ||= {}

    return unless user_history = opts[:user_history]

    if user.suspended_forever?
      build_email(
        user.email,
        template: "user_notifications.account_suspended_forever",
        locale: user_locale(user),
        reason: user_history.details,
      )
    else
      suspended_till = user.suspended_till.in_time_zone(user.user_option.timezone.presence || "UTC")
      build_email(
        user.email,
        template: "user_notifications.account_suspended",
        locale: user_locale(user),
        reason: user_history.details,
        suspended_till: I18n.l(suspended_till, format: :long),
      )
    end
  end

  def account_exists(user, opts = {})
    build_email(
      user.email,
      template: "user_notifications.account_exists",
      locale: user_locale(user),
      email: user.email,
    )
  end

  def account_second_factor_disabled(user, opts = {})
    build_email(
      user.email,
      template: "user_notifications.account_second_factor_disabled",
      locale: user_locale(user),
      email: user.email,
    )
  end

  def digest(user, opts = {})
    build_summary_for(user)
    @unsubscribe_key = UnsubscribeKey.create_key_for(@user, UnsubscribeKey::DIGEST_TYPE)

    @since = opts[:since].presence
    @since ||= [user.last_seen_at, user.user_stat&.digest_attempted_at, 1.month.ago].compact.max

    # Fetch some topics and posts to show
    digest_opts = {
      limit: SiteSetting.digest_topics + SiteSetting.digest_other_topics,
      top_order: true,
    }
    topics_for_digest = Topic.for_digest(user, @since, digest_opts)
    if topics_for_digest.empty? && !user.user_option.try(:include_tl0_in_digests)
      # Find some topics from new users that are at least 24 hours old
      topics_for_digest =
        Topic.for_digest(user, @since, digest_opts.merge(include_tl0: true)).where(
          "topics.created_at < ?",
          24.hours.ago,
        )
    end

    @popular_topics = topics_for_digest[0, SiteSetting.digest_topics]

    if @popular_topics.present?
      @other_new_for_you =
        (
          if topics_for_digest.size > SiteSetting.digest_topics
            topics_for_digest[SiteSetting.digest_topics..-1]
          else
            []
          end
        )

      @popular_posts =
        if SiteSetting.digest_posts > 0
          Post
            .order("posts.score DESC")
            .for_mailing_list(user, @since)
            .where("posts.post_type = ?", Post.types[:regular])
            .where(
              "posts.deleted_at IS NULL AND posts.hidden = false AND posts.user_deleted = false",
            )
            .where(
              "posts.post_number > ? AND posts.score > ?",
              1,
              ScoreCalculator.default_score_weights[:like_score] * 5.0,
            )
            .where("posts.created_at < ?", (SiteSetting.editing_grace_period || 0).seconds.ago)
            .limit(SiteSetting.digest_posts)
        else
          []
        end

      @excerpts = {}

      @popular_topics.each do |t|
        next if t.first_post.blank?
        @excerpts[t.first_post.id] = email_excerpt(t.first_post.cooked, t.first_post)
      end

      # Try to find 3 interesting stats for the top of the digest
      new_topics_count = Topic.for_digest(user, @since).count
      # We used topics from new users instead, so count should match
      new_topics_count = topics_for_digest.size if new_topics_count == 0

      @counts = [
        {
          id: "new_topics",
          label_key: "user_notifications.digest.new_topics",
          value: new_topics_count,
          href: "#{Discourse.base_url}/new",
        },
      ]

      # totalling unread notifications (which are low-priority only) and unread
      # PMs and bookmark reminder notifications, so the total is both unread low
      # and high priority PMs
      value = user.unread_notifications + user.unread_high_priority_notifications
      if value > 0
        @counts << {
          id: "unread_notifications",
          label_key: "user_notifications.digest.unread_notifications",
          value: value,
          href: "#{Discourse.base_url}/my/notifications",
        }
      end

      if @counts.size < 3
        value = user.unread_notifications_of_type(Notification.types[:liked], since: @since)
        if value > 0
          @counts << {
            id: "likes_received",
            label_key: "user_notifications.digest.liked_received",
            value: value,
            href: "#{Discourse.base_url}/my/notifications",
          }
        end
      end

      if @counts.size < 3 && user.user_option.digest_after_minutes.to_i >= 1440
        value = summary_new_users_count(@since)
        if value > 0
          @counts << {
            id: "new_users",
            label_key: "user_notifications.digest.new_users",
            value: value,
            href: "#{Discourse.base_url}/about",
          }
        end
      end

      @preheader_text = I18n.t("user_notifications.digest.preheader", since: @since)

      opts = {
        from_alias: I18n.t("user_notifications.digest.from", site_name: Email.site_title),
        subject:
          I18n.t(
            "user_notifications.digest.subject_template",
            email_prefix: @email_prefix,
            date: short_date(Time.now),
          ),
        add_unsubscribe_link: true,
        unsubscribe_url: "#{Discourse.base_url}/email/unsubscribe/#{@unsubscribe_key}",
        topic_ids: topics_for_digest.pluck(:id),
        post_ids:
          topics_for_digest.joins(:posts).where(posts: { post_number: 1 }).pluck("posts.id"),
      }

      build_email(user.email, opts)
    end
  end

  def user_replied(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    opts[:show_tags_in_subject] = true
    notification_email(user, opts)
  end

  def user_quoted(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    opts[:show_tags_in_subject] = true
    notification_email(user, opts)
  end

  def user_linked(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    opts[:show_tags_in_subject] = true
    notification_email(user, opts)
  end

  def user_mentioned(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    opts[:show_tags_in_subject] = true

    notification_email(user, opts)
  end

  def group_mentioned(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:show_category_in_subject] = true
    opts[:show_tags_in_subject] = true
    notification_email(user, opts)
  end

  def user_posted(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:add_re_to_subject] = true
    opts[:show_category_in_subject] = true
    opts[:show_tags_in_subject] = true
    notification_email(user, opts)
  end

  def user_private_message(user, opts)
    opts[:allow_reply_by_email] = true
    opts[:use_site_subject] = true
    opts[:add_re_to_subject] = true
    opts[:show_category_in_subject] = false
    opts[:show_tags_in_subject] = false
    opts[:show_group_in_subject] = true if SiteSetting.group_in_subject

    # We use the 'user_posted' event when you are emailed a post in a PM.
    opts[:notification_type] = "posted"

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
    opts[:show_tags_in_subject] = true
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
      show_tags_in_subject: true,
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
    user.effective_locale
  end

  def email_post_markdown(post, add_posted_by = false)
    result = +"#{post.raw}\n\n"
    if add_posted_by
      result << "#{I18n.t("user_notifications.posted_by", username: post.username, post_date: post.created_at.strftime("%m/%d/%Y"))}\n\n"
    end
    result
  end

  def self.get_context_posts(post, topic_user, user)
    if (user.user_option.email_previous_replies == UserOption.previous_replies_type[:never]) ||
         SiteSetting.private_email?
      return []
    end

    allowed_post_types = [Post.types[:regular]]
    allowed_post_types << Post.types[:whisper] if topic_user.try(:user).try(:staff?)

    context_posts =
      Post
        .where(topic_id: post.topic_id)
        .where("post_number < ?", post.post_number)
        .where(user_deleted: false)
        .where(hidden: false)
        .where(post_type: allowed_post_types)
        .order("created_at desc")
        .limit(SiteSetting.email_posts_context)

    if topic_user && topic_user.last_emailed_post_number &&
         user.user_option.email_previous_replies ==
           UserOption.previous_replies_type[:unless_emailed]
      context_posts = context_posts.where("post_number > ?", topic_user.last_emailed_post_number)
    end

    context_posts
  end

  def notification_email(user, opts)
    notification_type = opts[:notification_type]
    notification_data = opts[:notification_data_hash]
    post = opts[:post]

    unless String === notification_type
      notification_type = Notification.types[notification_type] if Numeric === notification_type
      notification_type = notification_type.to_s
    end

    user_name = notification_data[:original_username]

    if post && SiteSetting.enable_names && SiteSetting.display_name_on_email_from
      name = User.where(id: notification_data[:original_user_id] || post.user_id).pick(:name)
      user_name = name if name.present?
    end

    allow_reply_by_email = opts[:allow_reply_by_email] unless user.suspended?
    original_username =
      notification_data[:original_username] || notification_data[:display_username]

    if user.staged && post
      original_subject =
        IncomingEmail
          .joins(:post)
          .where("posts.topic_id = ? AND posts.post_number = 1", post.topic_id)
          .pluck(:subject)
          .first
    end

    if original_subject
      topic_title = original_subject
      opts[:use_site_subject] = false
      opts[:add_re_to_subject] = true
      use_topic_title_subject = true
    else
      topic_title = notification_data[:topic_title]
      use_topic_title_subject = false
    end

    email_options = {
      title: topic_title,
      post: post,
      username: original_username,
      from_alias: I18n.t("email_from", user_name: user_name, site_name: Email.site_title),
      allow_reply_by_email: allow_reply_by_email,
      use_site_subject: opts[:use_site_subject],
      add_re_to_subject: opts[:add_re_to_subject],
      show_category_in_subject: opts[:show_category_in_subject],
      show_tags_in_subject: opts[:show_tags_in_subject],
      show_group_in_subject: opts[:show_group_in_subject],
      notification_type: notification_type,
      use_invite_template: opts[:use_invite_template],
      use_topic_title_subject: use_topic_title_subject,
      user: user,
    }

    email_options =
      DiscoursePluginRegistry.apply_modifier(:user_notification_email_options, email_options)

    if group_id = notification_data[:group_id]
      email_options[:group_name] = Group.find_by(id: group_id)&.name
    end

    send_notification_email(email_options)
  end

  def send_notification_email(opts)
    post = opts[:post]
    title = opts[:title]

    allow_reply_by_email = opts[:allow_reply_by_email]
    use_site_subject = opts[:use_site_subject]
    add_re_to_subject = opts[:add_re_to_subject] && post.post_number > 1
    use_topic_title_subject = opts[:use_topic_title_subject]
    username = opts[:username]
    from_alias = opts[:from_alias]
    notification_type = opts[:notification_type]
    user = opts[:user]
    group_name = opts[:group_name]
    locale = user_locale(user)

    template = +"user_notifications.user_#{notification_type}"
    if post.topic.private_message?
      template << "_pm"

      if group_name
        template << "_group"
      elsif user.staged
        template << "_staged"
      end
    end

    # category name
    category = Topic.find_by(id: post.topic_id)&.category
    if opts[:show_category_in_subject] && post.topic_id && category && !category.uncategorized?
      show_category_in_subject = category.name

      # subcategory case
      if !category.parent_category_id.nil?
        show_category_in_subject =
          "#{Category.where(id: category.parent_category_id).pick(:name)}/#{show_category_in_subject}"
      end
    else
      show_category_in_subject = nil
    end

    # tag names
    if opts[:show_tags_in_subject] && post.topic_id
      max_tags =
        if SiteSetting.enable_max_tags_per_email_subject
          SiteSetting.max_tags_per_email_subject
        else
          SiteSetting.max_tags_per_topic
        end

      tags =
        DiscourseTagging
          .visible_tags(Guardian.new(user))
          .joins(:topic_tags)
          .where("topic_tags.topic_id = ?", post.topic_id)
          .order("tags.public_topic_count DESC", "tags.name ASC")
          .limit(max_tags)
          .pluck(:name)

      show_tags_in_subject = tags.any? ? tags.join(" ") : nil
    end

    group = post.topic.allowed_groups&.first

    if post.topic.private_message?
      subject_pm =
        if opts[:show_group_in_subject] && group.present?
          if group.full_name
            "[#{group.full_name}] "
          else
            "[#{group.name}] "
          end
        else
          I18n.t("subject_pm")
        end

      participants = self.class.participants(post, user)
    end

    if SiteSetting.private_email?
      title = I18n.t("system_messages.private_topic_title", id: post.topic_id)
    end

    context = +""
    tu = TopicUser.get(post.topic_id, user)
    context_posts = self.class.get_context_posts(post, tu, user)

    # make .present? cheaper
    context_posts = context_posts.to_a

    if context_posts.present?
      context << +"-- \n*#{I18n.t("user_notifications.previous_discussion")}*\n"
      context_posts.each { |cp| context << email_post_markdown(cp, true) }
    end

    translation_override_exists =
      TranslationOverride.where(
        locale: SiteSetting.default_locale,
        translation_key: "#{template}.text_body_template",
      ).exists?

    if opts[:use_invite_template]
      invite_template = +"user_notifications.invited"
      invite_template << "_group" if group_name

      invite_template << if post.topic.private_message?
        "_to_private_message_body"
      else
        "_to_topic_body"
      end

      topic_excerpt = post.excerpt.tr("\n", " ") if post.is_first_post? && post.excerpt
      topic_url = post.topic&.url

      if SiteSetting.private_email?
        topic_excerpt = ""
        topic_url = ""
      end

      message =
        I18n.t(
          invite_template,
          username: username,
          group_name: group_name,
          topic_title: gsub_emoji_to_unicode(title),
          topic_excerpt: topic_excerpt,
          site_title: SiteSetting.title,
          site_description: SiteSetting.site_description,
          topic_url: topic_url,
        )

      html = PrettyText.cook(message, sanitize: false).html_safe
    else
      reached_limit = SiteSetting.max_emails_per_day_per_user > 0
      reached_limit &&=
        (EmailLog.where(user_id: user.id).where("created_at > ?", 1.day.ago).count) >=
          (SiteSetting.max_emails_per_day_per_user - 1)

      in_reply_to_post = post.reply_to_post if user.user_option.email_in_reply_to

      if SiteSetting.private_email?
        message = I18n.t("system_messages.contents_hidden")
      else
        message =
          email_post_markdown(post) +
            (
              if reached_limit
                "\n\n#{I18n.t "user_notifications.reached_limit", count: SiteSetting.max_emails_per_day_per_user}"
              else
                ""
              end
            )
      end

      first_footer_classes = "highlight"
      if (allow_reply_by_email && user.staged) || (user.suspended? || user.staged?)
        first_footer_classes = ""
      end

      unless translation_override_exists
        html =
          UserNotificationRenderer.render(
            template: "email/notification",
            format: :html,
            locals: {
              context_posts: context_posts,
              reached_limit: reached_limit,
              post: post,
              in_reply_to_post: in_reply_to_post,
              classes: Rtl.new(user).css_class,
              first_footer_classes: first_footer_classes,
              reply_above_line: false,
            },
          )
      end
    end

    email_opts = {
      topic_title: Emoji.gsub_emoji_to_unicode(title),
      topic_title_url_encoded: title ? UrlHelper.encode_component(title) : title,
      message: message,
      url: post.url(without_slug: SiteSetting.private_email?),
      post_id: post.id,
      topic_id: post.topic_id,
      context: context,
      username: username,
      group_name: group_name,
      add_unsubscribe_link: !user.staged,
      mailing_list_mode: user.user_option.mailing_list_mode,
      unsubscribe_url: post.unsubscribe_url(user),
      allow_reply_by_email: allow_reply_by_email,
      only_reply_by_email: allow_reply_by_email && user.staged,
      use_site_subject: use_site_subject,
      add_re_to_subject: add_re_to_subject,
      show_category_in_subject: show_category_in_subject,
      show_tags_in_subject: show_tags_in_subject,
      private_reply: post.topic.private_message?,
      subject_pm: subject_pm,
      participants: participants,
      include_respond_instructions: !(user.suspended? || user.staged?),
      notification_type: notification_type,
      template: template,
      use_topic_title_subject: use_topic_title_subject,
      site_description: SiteSetting.site_description,
      site_title: SiteSetting.title,
      site_title_url_encoded: UrlHelper.encode_component(SiteSetting.title),
      locale: locale,
    }

    email_opts[:html_override] = html unless translation_override_exists

    # If we have a display name, change the from address
    email_opts[:from_alias] = from_alias if from_alias.present?

    TopicUser.change(user.id, post.topic_id, last_emailed_post_number: post.post_number)

    build_email(user.email, email_opts)
  end

  def self.participants(post, recipient_user, reveal_staged_email: false)
    list = []

    allowed_groups = post.topic.allowed_groups.order("user_count DESC")

    allowed_groups.each do |g|
      list.push("[#{g.name_full_preferred} (#{g.user_count})](#{g.full_url})")
      break if list.size >= SiteSetting.max_participant_names
    end

    recent_posts_query =
      post
        .topic
        .posts
        .select("user_id, MAX(post_number) AS post_number")
        .where(post_type: Post.types[:regular], post_number: ..post.post_number)
        .where.not(user_id: recipient_user.id)
        .group(:user_id)
        .order("post_number DESC")
        .limit(SiteSetting.max_participant_names)
        .to_sql

    allowed_users =
      post
        .topic
        .allowed_users
        .joins("LEFT JOIN (#{recent_posts_query}) pu ON topic_allowed_users.user_id = pu.user_id")
        .order("post_number DESC NULLS LAST", :id)
        .where.not(id: recipient_user.id)
        .human_users

    allowed_users.each do |u|
      break if list.size >= SiteSetting.max_participant_names

      if reveal_staged_email && u.staged?
        list.push("#{u.email}")
      else
        list.push("[#{u.display_name}](#{u.full_url})")
      end
    end

    participants = list.join(I18n.t("word_connector.comma"))
    others_count = allowed_groups.size + allowed_users.size - list.size

    if others_count > 0
      I18n.t(
        "user_notifications.more_pm_participants",
        participants: participants,
        count: others_count,
      )
    else
      participants
    end
  end

  private

  def build_user_email_token_by_template(template, user, email_token)
    build_email(user.email, template: template, locale: user_locale(user), email_token: email_token)
  end

  def build_summary_for(user)
    @site_name = SiteSetting.email_prefix.presence || SiteSetting.title
    @user = user
    @date = short_date(Time.now)
    @base_url = Discourse.base_url
    @email_prefix = SiteSetting.email_prefix.presence || SiteSetting.title
    @header_color = ColorScheme.hex_for_name("header_primary")
    @header_bgcolor = ColorScheme.hex_for_name("header_background")
    @anchor_color = ColorScheme.hex_for_name("tertiary")
    @markdown_linker = MarkdownLinker.new(@base_url)
    @disable_email_custom_styles = !SiteSetting.apply_custom_styles_to_digest
  end

  def summary_new_users_count(since)
    date = since.is_a?(String) ? since : since.strftime("%Y-%m-%d")
    key = "summary-new-users:#{date}"
    Discourse.redis.get(key)&.to_i ||
      User
        .real
        .activated
        .not_staged
        .not_suspended
        .where("created_at > ?", date)
        .count
        .tap { Discourse.redis.setex(key, 1.day, _1) }
  end
end
