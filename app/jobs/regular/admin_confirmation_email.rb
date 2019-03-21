require_dependency 'email/sender'

module Jobs
  class AdminConfirmationEmail < Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      to_address = args[:to_address]
      token = args[:token]
      target_username = args[:target_username]

      raise Discourse::InvalidParameters.new(:to_address) if to_address.blank?
      raise Discourse::InvalidParameters.new(:token) if token.blank?
      if target_username.blank?
        raise Discourse::InvalidParameters.new(:target_username)
      end

      message =
        AdminConfirmationMailer.send_email(to_address, target_username, token)
      Email::Sender.new(message, :admin_confirmation_message).send
    end
  end
end
