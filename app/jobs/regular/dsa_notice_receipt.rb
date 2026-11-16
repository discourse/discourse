# frozen_string_literal: true

module Jobs
  class DsaNoticeReceipt < ::Jobs::Base
    def execute(args)
      notice = Dsa::Notice.find_by(id: args[:notice_id])
      if !notice || !notice.post || notice.post.deleted_at || notice.email.blank? ||
           notice.receipt_sent?
        return
      end

      sent = Email::Sender.new(DsaNoticeMailer.receipt(notice), :dsa_notice_receipt).send
      notice.mark_receipt_sent! if sent.is_a?(EmailLog) && sent.persisted?
    end
  end
end
