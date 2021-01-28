# frozen_string_literal: true

require_dependency 'email/message_builder'

class GroupSmtpMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_mail(from_group, to_address, post)
    raise 'SMTP is disabled' if !SiteSetting.enable_smtp

    incoming_email = IncomingEmail.joins(:post)
      .where('imap_uid IS NOT NULL')
      .where(topic_id: post.topic_id, posts: { post_number: 1 })
      .limit(1).first

    context_posts = Post
      .where(topic_id: post.topic_id)
      .where("post_number < ?", post.post_number)
      .where(user_deleted: false)
      .where(hidden: false)
      .where(post_type: Post.types[:regular])
      .order(created_at: :desc)
      .limit(SiteSetting.email_posts_context)
      .to_a

    delivery_options = {
      address: from_group.smtp_server,
      port: from_group.smtp_port,
      domain: from_group.email_username.split('@').last,
      user_name: from_group.email_username,
      password: from_group.email_password,
      authentication: GlobalSetting.smtp_authentication,
      enable_starttls_auto: from_group.smtp_ssl
    }

    user_name = post.user.username
    if SiteSetting.enable_names && SiteSetting.display_name_on_email_from
      user_name = post.user.name unless post.user.name.blank?
    end

    build_email(to_address,
      message: post.raw,
      url: post.url(without_slug: SiteSetting.private_email?),
      post_id: post.id,
      topic_id: post.topic_id,
      context: context(context_posts),
      username: post.user.username,
      group_name: from_group.name,
      allow_reply_by_email: true,
      only_reply_by_email: true,
      use_from_address_for_reply_to: from_group.imap_enabled?,
      private_reply: post.topic.private_message?,
      participants: participants(post),
      include_respond_instructions: true,
      template: 'user_notifications.user_posted_pm',
      use_topic_title_subject: true,
      topic_title: incoming_email&.subject || post.topic.title,
      add_re_to_subject: true,
      locale: SiteSetting.default_locale,
      delivery_method_options: delivery_options,
      from: from_group.email_username,
      from_alias: I18n.t('email_from', user_name: user_name, site_name: Email.site_title),
      html_override: html_override(post, context_posts: context_posts)
    )
  end

  private

  def context(context_posts)
    return "" if SiteSetting.private_email?

    context = +""

    if context_posts.size > 0
      context << +"-- \n*#{I18n.t('user_notifications.previous_discussion')}*\n"
      context_posts.each { |post| context << email_post_markdown(post, true) }
    end

    context
  end

  def email_post_markdown(post, add_posted_by = false)
    result = +"#{post.raw}\n\n"
    if add_posted_by
      result << "#{I18n.t('user_notifications.posted_by', username: post.username, post_date: post.created_at.strftime("%m/%d/%Y"))}\n\n"
    end
    result
  end

  def html_override(post, context_posts: nil)
    UserNotificationRenderer.render(
      template: 'email/notification',
      format: :html,
      locals: {
        context_posts: context_posts,
        reached_limit: nil,
        post: post,
        in_reply_to_post: post.reply_to_post,
        classes: Rtl.new(nil).css_class,
        first_footer_classes: ''
      }
    )
  end

  def participants(post)
    list = []

    post.topic.allowed_groups.each do |g|
      list.push("[#{g.name} (#{g.users.count})](#{Discourse.base_url}/groups/#{g.name})")
    end

    post.topic.allowed_users.each do |u|
      if SiteSetting.prioritize_username_in_ux?
        list.push("[#{u.username}](#{Discourse.base_url}/u/#{u.username_lower})")
      else
        list.push("[#{u.name.blank? ? u.username : u.name}](#{Discourse.base_url}/u/#{u.username_lower})")
      end
    end

    list.join(', ')
  end
end
