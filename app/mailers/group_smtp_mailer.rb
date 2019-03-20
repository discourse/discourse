require_dependency 'email/message_builder'

class GroupSmtpMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_mail(from_group, to_address, post)
    incoming_email = IncomingEmail.joins(:post)
      .where('imap_uid IS NOT NULL')
      .where(topic_id: post.topic_id, posts: { post_number: 1 })
      .limit(1).first

    delivery_options = {
      address: from_group.smtp_server,
      port: from_group.smtp_port,
      domain: from_group.email_username.split("@").last,
      user_name: from_group.email_username,
      password: from_group.email_password,
      authentication: GlobalSetting.smtp_authentication,
      enable_starttls_auto: from_group.smtp_ssl
    }

    build_email(to_address,
      delivery_method_options: delivery_options,
      from: from_group.email_username,
      subject: incoming_email.subject,
      add_re_to_subject: true,
      body: post.raw,
      post_id: post.id,
      topic_id: post.topic_id
    )
  end
end
