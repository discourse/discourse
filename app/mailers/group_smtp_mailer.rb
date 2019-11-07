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
      username: post.user.username,
      group_name: from_group.name,
      allow_reply_by_email: true,
      only_reply_by_email: true,
      private_reply: post.topic.private_message?,
      include_respond_instructions: true,
      template: 'user_notifications.user_posted_pm_staged',
      use_topic_title_subject: true,
      topic_title: incoming_email&.subject || post.topic.title,
      add_re_to_subject: true,
      locale: SiteSetting.default_locale,
      delivery_method_options: delivery_options,
      from: from_group.email_username,
      from_alias: I18n.t('email_from', user_name: user_name, site_name: Email.site_title),
    )
  end
end
