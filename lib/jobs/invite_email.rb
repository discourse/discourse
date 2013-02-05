require_dependency 'email_sender'

module Jobs

  # Asynchronously send an email
  class InviteEmail < Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:invite_id) unless args[:invite_id].present?

      invite = Invite.where(id: args[:invite_id]).first
      message = InviteMailer.send_invite(invite)
      EmailSender.new(message, :invite).send
    end

  end

end
