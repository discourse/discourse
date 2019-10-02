# frozen_string_literal: true

module Jobs

  # Asynchronously send an email
  class InvitePasswordInstructionsEmail < ::Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:username) unless args[:username].present?
      user = User.find_by_username_or_email(args[:username])
      message = InviteMailer.send_password_instructions(user)
      Email::Sender.new(message, :invite_password_instructions).send
    end

  end

end
