# frozen_string_literal: true

module Dsa
  class RequestNoticeVerification
    include Service::Base

    options { attribute :ip_address, :string }

    params do
      attribute :email, :string

      before_validation { self.email = email.to_s.strip.downcase }

      validates :email, presence: true, length: { maximum: 254 }
      validate :valid_email

      private

      def valid_email
        return if Email.is_valid?(email) && !email.match?(/[\r\n]/)
        errors.add(:email, I18n.t("dsa_notice.invalid_email"))
      end
    end

    step :rate_limit_notice
    model :token, :create_verification
    step :enqueue_verification

    private

    def rate_limit_notice(params:, options:)
      if options.ip_address.present?
        RateLimiter.new(nil, "dsa-notice-ip-#{options.ip_address}", 5, 1.hour).performed!
      end
      email_key = Digest::SHA256.hexdigest(params.email)
      email_limiter = RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day)
      email_limiter.performed!
      begin
        RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed!
      rescue RateLimiter::LimitExceeded
        email_limiter.rollback!
        raise
      end
    end

    def create_verification(params:)
      Dsa::NoticeVerification.create(params.email)
    end

    def enqueue_verification(token:)
      Jobs.enqueue(:dsa_notice_verification, token:)
    end
  end
end
