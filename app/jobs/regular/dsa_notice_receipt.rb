# frozen_string_literal: true

module Jobs
  class DsaNoticeReceipt < ::Jobs::Base
    def execute(args)
      DistributedMutex.synchronize("dsa-notice-receipt-#{args.fetch(:post_id)}") do
        notice = Dsa::Notice.from_post(Post.find_by(id: args[:post_id]))
        return if !notice || notice.email.blank? || notice.receipt_sent?

        sent = Email::Sender.new(DsaNoticeMailer.receipt(notice), :dsa_notice_receipt).send
        notice.mark_receipt_sent! if sent.is_a?(EmailLog) && sent.persisted?
      end
    end
  end
end
