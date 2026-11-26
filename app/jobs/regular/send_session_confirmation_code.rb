# frozen_string_literal: true

module Jobs
  class SendSessionConfirmationCode < ::Jobs::Base
    sidekiq_options queue: "critical"

    def execute(args)
      raise Discourse::InvalidParameters.new(:to_address) if args[:to_address].blank?
      raise Discourse::InvalidParameters.new(:code) if args[:code].blank?
      if SiteSetting.enable_discourse_connect || !SiteSetting.enable_local_logins ||
           !SiteSetting.enable_local_logins_via_email
        return
      end

      user = User.find_by(id: args[:user_id]) if args[:user_id].present?
      message =
        EmailLoginCodeMailer.send_code(
          args[:to_address],
          args[:code],
          purpose: :session_confirmation,
          user: user,
        )
      Email::Sender.new(message, :session_confirmation_code).send
    end
  end
end
