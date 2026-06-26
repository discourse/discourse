# frozen_string_literal: true

module Jobs
  class SendEmailLoginCode < ::Jobs::Base
    sidekiq_options queue: "critical"

    def execute(args)
      raise Discourse::InvalidParameters.new(:to_address) if args[:to_address].blank?
      raise Discourse::InvalidParameters.new(:code) if args[:code].blank?
      return if !SiteSetting.enable_local_logins_via_code

      message = EmailLoginCodeMailer.send_code(args[:to_address], args[:code])
      Email::Sender.new(message, :email_login_code).send
    end
  end
end
