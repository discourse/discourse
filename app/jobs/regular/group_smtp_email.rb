# frozen_string_literal: true

require_dependency 'email/sender'

module Jobs
  class GroupSmtpEmail < ::Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      group = Group.find_by(id: args[:group_id])
      post = Post.find_by(id: args[:post_id])
      email = args[:email]

      # There is a rare race condition causing the Imap::Sync class to create
      # an incoming email and associated post/topic, which then kicks off
      # the PostAlerter to notify others in the PM about a reply in the topic,
      # but for the OP which is not necessary (because the person emailing the
      # IMAP inbox already knows about the OP)
      #
      # Basically, we should never be sending this notification for the first
      # post in a topic.
      if post.is_first_post?
        ImapSyncLog.warn("Aborting SMTP email for post #{post.id} in topic #{post.topic_id} to #{email}, the post is the OP and should not send an email.", group)
        return
      end

      ImapSyncLog.debug("Sending SMTP email for post #{post.id} in topic #{post.topic_id} to #{email}.", group)

      recipient_user = ::UserEmail.find_by(email: email, primary: true)&.user
      message = GroupSmtpMailer.send_mail(group, email, post)
      Email::Sender.new(message, :group_smtp, recipient_user).send

      # Create an incoming email record to avoid importing again from IMAP
      # server.
      IncomingEmail.create!(
        user_id: post.user_id,
        topic_id: post.topic_id,
        post_id: post.id,
        raw: message.to_s,
        subject: message.subject,
        message_id: message.message_id,
        to_addresses: message.to,
        cc_addresses: message.cc,
        from_address: message.from,
        created_via: IncomingEmail.created_via_types[:group_smtp]
      )
    end
  end
end
