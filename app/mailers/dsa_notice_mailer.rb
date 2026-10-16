# frozen_string_literal: true

class DsaNoticeMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def receipt(notice)
    html_body =
      I18n.t(
        "dsa_notice_mailer.text_body_template",
        reference: notice.fetch("reference"),
        summary: notice.fetch("summary"),
        site_title: ERB::Util.html_escape(SiteSetting.title),
      )
    build_email(
      notice.fetch("email"),
      template: "dsa_notice_mailer",
      reference: notice.fetch("reference"),
      summary: notice.fetch("text_summary"),
      site_title: SiteSetting.title,
      html_override: PrettyText.cook(html_body),
    )
  end
end
