require_dependency 'markdown_linker'
require_dependency 'email/message_builder'
require_dependency 'age_words'

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
                new_user_tips: SiteText.text_for(:usage_tips))
  end

  def authorize_email(user, opts={})
    build_email(user.email, template: "user_notifications.authorize_email", email_token: opts[:email_token])
  end

  def forgot_password(user, opts={})
    build_email( user.email,
                 template: user.has_password? ? "user_notifications.forgot_password" : "user_notifications.set_password",
                 email_token: opts[:email_token])
  end

  def account_created(user, opts={})
    build_email( user.email, template: "user_notifications.account_created", email_token: opts[:email_token])
  end


  def digest(user, opts={})
    @user = user
    @base_url = Discourse.base_url

    min_date = opts[:since] || @user.last_emailed_at || @user.last_seen_at || 1.month.ago

    @site_name = SiteSetting.title

    @header_color = ColorScheme.hex_for_name('header_background')
    @last_seen_at = I18n.l(@user.last_seen_at || @user.created_at, format: :short)

    # A list of topics to show the user
    @featured_topics = Topic.for_digest(user, min_date, limit: SiteSetting.digest_topics, top_order: true).to_a

    # Don't send email unless there is content in it
    if @featured_topics.present?
      featured_topic_ids = @featured_topics.map(&:id)

      @new_topics_since_seen = Topic.new_since_last_seen(user, min_date, featured_topic_ids).count
      if @new_topics_since_seen > 1000
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
      @markdown_linker = MarkdownLinker.new(Discourse.base_url)

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

  def user_mentioned(user, opts)
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

  def mailing_list_notify(user, post)
    send_notification_email(
      title: post.topic.title,
      post: post,
      username: post.user.username,
      from_alias: SiteSetting.enable_email_names ? post.user.name : post.user.username,
      allow_reply_by_email: true,
      use_site_subject: true,
      add_re_to_subject: true,
      show_category_in_subject: true,
      notification_type: "posted",
      user: user
    )
  end

  protected

  def email_post_markdown(post)
    result = "[email-indent]\n"
    result << "#{post.raw}\n\n"
    result << "#{I18n.t('user_notifications.posted_by', username: post.username, post_date: post.created_at.strftime("%m/%d/%Y"))}\n\n"
    result << "[/email-indent]\n"
    result
  end

  class UserNotificationRenderer < ActionView::Base
    include UserNotificationsHelper
  end

  def self.get_context_posts(post, topic_user)

    context_posts = Post.where(topic_id: post.topic_id)
                        .where("post_number < ?", post.post_number)
                        .where(user_deleted: false)
                        .where(hidden: false)
                        .order('created_at desc')
                        .limit(SiteSetting.email_posts_context)

    if topic_user && topic_user.last_emailed_post_number
      context_posts = context_posts.where("post_number > ?", topic_user.last_emailed_post_number)
    end

    context_posts
  end

  def notification_email(user, opts)
    return unless @notification = opts[:notification]
    return unless @post = opts[:post]

    user_name = @notification.data_hash[:original_username]
    if @post && SiteSetting.enable_email_names
      user_name = User.find_by(id: @post.user_id).name
    end

    notification_type = opts[:notification_type] || Notification.types[@notification.notification_type].to_s

    return if user.mailing_list_mode && !@post.topic.private_message? &&
       ["replied", "mentioned", "quoted", "posted"].include?(notification_type)

    title = @notification.data_hash[:topic_title]
    allow_reply_by_email = opts[:allow_reply_by_email] unless user.suspended?
    use_site_subject = opts[:use_site_subject]
    add_re_to_subject = opts[:add_re_to_subject]
    show_category_in_subject = opts[:show_category_in_subject]

    send_notification_email(
      title: title,
      post: @post,
      username: @notification.data_hash[:original_username],
      from_alias: user_name,
      allow_reply_by_email: allow_reply_by_email,
      use_site_subject: use_site_subject,
      add_re_to_subject: add_re_to_subject,
      show_category_in_subject: show_category_in_subject,
      notification_type: notification_type,
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

    # category name
    category = Topic.find_by(id: post.topic_id).category
    if opts[:show_category_in_subject] && post.topic_id && !category.uncategorized?
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
    context_posts = self.class.get_context_posts(post, tu)

    # make .present? cheaper
    context_posts = context_posts.to_a

    if context_posts.present?
      context << "---\n*#{I18n.t('user_notifications.previous_discussion')}*\n"
      context_posts.each do |cp|
        context << email_post_markdown(cp)
      end
    end

    html = UserNotificationRenderer.new(Rails.configuration.paths["app/views"]).render(
      template: 'email/notification',
      format: :html,
      locals: { context_posts: context_posts,
                post: post,
                classes: RTL.new(user).css_class
      }
    )

    template = "user_notifications.user_#{notification_type}"
    if post.topic.private_message?
      template << "_pm"
    end

    email_opts = {
      topic_title: title,
      message: email_post_markdown(post),
      url: post.url,
      post_id: post.id,
      topic_id: post.topic_id,
      context: context,
      username: username,
      add_unsubscribe_link: true,
      allow_reply_by_email: allow_reply_by_email,
      use_site_subject: use_site_subject,
      add_re_to_subject: add_re_to_subject,
      show_category_in_subject: show_category_in_subject,
      private_reply: post.topic.private_message?,
      include_respond_instructions: !user.suspended?,
      template: template,
      html_override: html,
      style: :notification
    }

    # If we have a display name, change the from address
    if from_alias.present?
      email_opts[:from_alias] = from_alias
    end

    TopicUser.change(user.id, post.topic_id, last_emailed_post_number: post.post_number)

    build_email(user.email, email_opts)
  end
end
