require_dependency 'email/sender'

module Jobs

  # Asynchronously send an email
  class InviteEmail < Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:invite_id) unless args[:invite_id].present?

      invite = Invite.find_by(id: args[:invite_id])
      message = InviteMailer.send_invite(invite)
      Email::Sender.new(message, :invite).send
    end

  end

end
