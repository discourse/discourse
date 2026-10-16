# frozen_string_literal: true

class DsaNoticeMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def receipt(notice)
    html_body =
      I18n.t(
        "dsa_notice_mailer.text_body_template",
        reference: notice.reference,
        summary: notice.summary,
        site_title: ERB::Util.html_escape(SiteSetting.title),
      )
    build_email(
      notice.email,
      template: "dsa_notice_mailer",
      reference: notice.reference,
      summary: notice.summary(plain_text: true),
      site_title: SiteSetting.title,
      html_override: PrettyText.cook(html_body),
    )
  end
end
