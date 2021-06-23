# frozen_string_literal: true

require_dependency 'email/sender'

module Jobs
  class GroupSmtpEmail < ::Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      group = Group.find_by(id: args[:group_id])
      post = Post.find_by(id: args[:post_id])
      email = args[:email]
      cc_addresses = args[:cc_emails]

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
      message = GroupSmtpMailer.send_mail(group, email, post, cc_addresses)

      # The EmailLog record created by Email::Sender is used to avoid double
      # importing from IMAP. Previously IncomingEmail was used, but it did
      # not make sense to make an IncomingEmail record for outbound emails.
      #
      # Note: (martin) IMAP syncing is currently broken by this change,
      # we need to revisit at a later date.
      Email::Sender.new(message, :group_smtp, recipient_user).send
    end
  end
end
