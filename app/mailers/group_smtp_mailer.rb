# frozen_string_literal: true

require_dependency 'email/message_builder'

class GroupSmtpMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_mail(from_group, to_address, post, cc_addresses = nil)
    raise 'SMTP is disabled' if !SiteSetting.enable_smtp

    op_incoming_email = post.topic.first_post.incoming_email
    recipient_user = User.find_by_email(to_address, primary: true)

    delivery_options = {
      address: from_group.smtp_server,
      port: from_group.smtp_port,
      domain: from_group.email_username_domain,
      user_name: from_group.email_username,
      password: from_group.email_password,
      authentication: GlobalSetting.smtp_authentication,
      enable_starttls_auto: from_group.smtp_ssl
    }

    user_name = post.user.username
    if SiteSetting.enable_names && SiteSetting.display_name_on_email_from
      user_name = post.user.name unless post.user.name.blank?
    end

    group_name = from_group.name_full_preferred
    build_email(
      to_address,
      message: post.raw,
      url: post.url(without_slug: SiteSetting.private_email?),
      post_id: post.id,
      topic_id: post.topic_id,
      context: "",
      username: post.user.username,
      group_name: group_name,
      allow_reply_by_email: true,
      only_reply_by_email: true,
      use_from_address_for_reply_to: SiteSetting.enable_smtp && from_group.smtp_enabled?,
      private_reply: post.topic.private_message?,
      participants: participants(post, recipient_user),
      include_respond_instructions: true,
      template: 'user_notifications.user_posted_pm',
      use_topic_title_subject: true,
      topic_title: op_incoming_email&.subject || post.topic.title,
      add_re_to_subject: true,
      locale: SiteSetting.default_locale,
      delivery_method_options: delivery_options,
      from: from_group.smtp_from_address,
      from_alias: I18n.t('email_from_without_site', user_name: group_name),
      html_override: html_override(post),
      cc: cc_addresses
    )
  end

  private

  def html_override(post)
    UserNotificationRenderer.render(
      template: 'email/notification',
      format: :html,
      locals: {
        context_posts: nil,
        reached_limit: nil,
        post: post,
        in_reply_to_post: nil,
        classes: Rtl.new(nil).css_class,
        first_footer_classes: '',
        reply_above_line: true
      }
    )
  end

  def participants(post, recipient_user)
    list = []

    post.topic.allowed_groups.each do |g|
      list.push("[#{g.name_full_preferred}](#{Discourse.base_url}/groups/#{g.name})")
    end

    post.topic.allowed_users.each do |u|
      next if u.id == recipient_user.id

      if SiteSetting.prioritize_username_in_ux?
        if u.staged?
          list.push("#{u.email}")
        else
          list.push("[#{u.username}](#{Discourse.base_url}/u/#{u.username_lower})")
        end
      else
        if u.staged?
          list.push("#{u.email}")
        else
          list.push("[#{u.name.blank? ? u.username : u.name}](#{Discourse.base_url}/u/#{u.username_lower})")
        end
      end
    end

    list.join(', ')
  end
end
