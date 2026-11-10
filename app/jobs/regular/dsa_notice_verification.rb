# frozen_string_literal: true

module Jobs
  class DsaNoticeVerification < ::Jobs::Base
    def execute(args)
      submission = Dsa::NoticeVerification.find(args[:token])
      return unless submission&.dig(:code)

      Email::Sender.new(
        DsaNoticeMailer.verification(email: submission[:email], code: submission[:code]),
        :dsa_notice_verification,
      ).send
    end
  end
end
