require_dependency 'email/sender'

module Jobs

  class GroupSmtpEmail < Jobs::Base
    include Skippable

    sidekiq_options queue: 'critical'

    def execute(args)
      group = Group.find_by(id: args[:group_id])
      post = Post.find_by(id: args[:post_id])
      email = args[:email]

      message = GroupSmtpMailer.send_mail(group, email, post)
      Email::Sender.new(message, :group_smtp).send
    end

  end

end
