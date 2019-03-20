require_dependency 'email/sender'

module Jobs

  class GroupSmtpEmail < Jobs::Base
    include Skippable

    sidekiq_options queue: 'critical'

    def execute(args)
      group = Group.find_by(id: args[:group_id])
      email = args[:email]
      post = Post.find_by(id: args[:post_id])

      message = GroupSmtpMailer.send_mail(group, email, post)
      Email::Sender.new(message, :group_smtp).send

      # Creating an entry to avoid syncing it again when reading email.
      IncomingEmail.create(
        message_id: message.message_id.presence || Digest::MD5.hexdigest(message.to_s),
        raw: message.to_s,
        subject: message.subject,
        from_address: message.from,
        to_addresses: message.to&.map(&:downcase)&.join(";"),
        cc_addresses: message.cc&.map(&:downcase)&.join(";")
      )
    end

  end

end
