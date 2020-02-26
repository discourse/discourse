# frozen_string_literal: true

require_dependency 'email/sender'

module Jobs
  class GroupSmtpEmail < ::Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      group = Group.find_by(id: args[:group_id])
      post = Post.find_by(id: args[:post_id])
      email = args[:email]

      Rails.logger.debug("[IMAP] Sending email for group #{group.name} and post #{post.id}")
      message = GroupSmtpMailer.send_mail(group, email, post)
      Email::Sender.new(message, :group_smtp).send

      # Create an incoming email record to avoid importing again from IMAP
      # server.
      IncomingEmail.create!(
        user_id: post.user_id,
        topic_id: post.topic_id,
        post_id: post.id,
        raw: message.to_s,
        message_id: message.message_id
      )
    end
  end
end
