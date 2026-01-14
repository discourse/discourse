# frozen_string_literal: true

class AiReportMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_report(to_address, opts = {})
    build_email(to_address, **opts)
  end
end
