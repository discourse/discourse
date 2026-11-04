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
      Dsa::NoticeRateLimiter.perform(email: params.email, ip_address: options.ip_address)
    end

    def create_verification(params:)
      Dsa::NoticeVerification.create(params.email)
    end

    def enqueue_verification(token:)
      Jobs.enqueue(:dsa_notice_verification, token:)
    end
  end
end
