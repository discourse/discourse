# frozen_string_literal: true

class GroupSmtpMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_mail(from_group, to_address, post, cc_addresses: nil, bcc_addresses: nil)
    raise "SMTP is disabled" if !SiteSetting.enable_smtp

    op_incoming_email = post.topic.first_post.incoming_email
    recipient_user = User.find_by_email(to_address, primary: true)

    delivery_options = {
      address: from_group.smtp_server,
      port: from_group.smtp_port,
      domain: from_group.email_username_domain,
      user_name: from_group.email_username,
      password: from_group.email_password,
      authentication: GlobalSetting.smtp_authentication,
      enable_starttls_auto: from_group.smtp_ssl,
      return_response: true,
    }

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
      participants: UserNotifications.participants(post, recipient_user, reveal_staged_email: true),
      include_respond_instructions: true,
      template: "user_notifications.user_posted_pm",
      use_topic_title_subject: true,
      topic_title: op_incoming_email&.subject || post.topic.title,
      add_re_to_subject: !post.is_first_post?,
      locale: SiteSetting.default_locale,
      delivery_method_options: delivery_options,
      from: from_group.smtp_from_address,
      from_alias: I18n.t("email_from_without_site", group_name: group_name),
      html_override: html_override(post),
      cc: cc_addresses,
      bcc: bcc_addresses,
    )
  end

  private

  def html_override(post)
    UserNotificationRenderer.render(
      template: "email/notification",
      format: :html,
      locals: {
        context_posts: nil,
        reached_limit: nil,
        post: post,
        in_reply_to_post: nil,
        classes: Rtl.new(nil).css_class,
        first_footer_classes: "",
        reply_above_line: true,
      },
    )
  end
end
