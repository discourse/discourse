# frozen_string_literal: true

module DiscourseAutomation
  class FlagMailer < ActionMailer::Base
    include Email::BuildEmailHelper

    def send_flag_email(to_address, subject:, body:)
      build_email(
        to_address,
        subject: subject,
        body: body,
        add_unsubscribe_link: false,
        allow_reply_by_email: false,
      )
    end
  end
end
