# frozen_string_literal: true

module Dsa
  class VerifyNoticeEmail
    include Service::Base

    params do
      attribute :token, :string
      attribute :email, :string
      attribute :verification_code, :string

      before_validation { self.email = email.to_s.strip.downcase }

      validates :token, presence: true, length: { is: 64 }
      validates :email, presence: true, length: { maximum: 254 }
      validates :verification_code, format: { with: /\A[0-9]{6}\z/ }
    end

    model :verification

    private

    def fetch_verification(params:)
      Dsa::NoticeVerification.verify(
        token: params.token,
        email: params.email,
        code: params.verification_code,
      )
    end
  end
end
