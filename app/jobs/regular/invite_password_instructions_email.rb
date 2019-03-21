require_dependency 'email/sender'

module Jobs
  # Asynchronously send an email
  class InvitePasswordInstructionsEmail < Jobs::Base
    def execute(args)
      unless args[:username].present?
        raise Discourse::InvalidParameters.new(:username)
      end
      user = User.find_by_username_or_email(args[:username])
      message = InviteMailer.send_password_instructions(user)
      Email::Sender.new(message, :invite_password_instructions).send
    end
  end
end
