# frozen_string_literal: true

module Jobs
  class AdminConfirmationEmail < ::Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      to_address = args[:to_address]
      token = args[:token]
      target_email = args[:target_email]
      target_username = args[:target_username]

      raise Discourse::InvalidParameters.new(:to_address) if to_address.blank?
      raise Discourse::InvalidParameters.new(:token) if token.blank?
      raise Discourse::InvalidParameters.new(:target_email) if target_email.blank?
      raise Discourse::InvalidParameters.new(:target_username) if target_username.blank?

      message = AdminConfirmationMailer.send_email(to_address, target_email, target_username, token)
      Email::Sender.new(message, :admin_confirmation_message).send
    end

  end
end
